// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//! Downstream transport qualification. The echo image validates the native
//! boundary, not ASCENT admission or the production Context service export.
use gerbil_scheme::instances::{InstanceConfig, InstanceError, InstancePool, IsolatedProgram};
use std::{error::Error, path::PathBuf, sync::mpsc, time::Duration};

fn main() -> Result<(), Box<dyn Error>> {
    let image = PathBuf::from(
        std::env::args_os()
            .nth(1)
            .ok_or("missing qualified image")?,
    );
    // SAFETY: the runner admits an explicit upstream qualification image with
    // its strong-root native export (string input is echoed after GC). No caller-controlled symbol is resolved.
    // Image unload is not opted in: callback quiescence is a separate contract.
    let program = unsafe { IsolatedProgram::from_image(image, c"gerbil_owner_native_call")? };
    let mut pool = InstancePool::start(
        &program,
        InstanceConfig {
            owners: 2,
            queue_capacity: 2,
            maximum_request_bytes: 4096,
            maximum_reply_bytes: 4096,
            startup_timeout: Duration::from_secs(10),
        },
    )?;
    let dispatcher = pool.dispatcher();
    dispatcher.configure_owner_capacity(1)?;
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_time()
        .build()?;
    let result = runtime.block_on(async {
        let (entered, started) = tokio::sync::oneshot::channel();
        let (release, gate) = mpsc::sync_channel(1);
        let ticket = dispatcher.submit_native_async_on(0, move |session| {
            let _ = entered.send(());
            // Directed rendezvous, not a service-time benchmark. Rust cannot
            // reclaim this owner's credit while its accepted call remains live.
            gate.recv_timeout(Duration::from_secs(5))
                .map_err(|_| InstanceError::Timeout)?;
            let input = session.string("original-envelope:ctx-A:epoch-1:attempt-0")?;
            let output = session.call(&input)?;
            session.copy_string(&output)
        })?;
        started.await.map_err(|_| InstanceError::Closed)?;
        let mut observed = Box::pin(ticket.wait_completed(Duration::from_secs(5)));
        // Retain the observation future: dropping a Tokio waiter is not a
        // Context cancel command and cannot manufacture an Attempt terminal.
        assert!(
            tokio::time::timeout(Duration::from_millis(2), &mut observed)
                .await
                .is_err()
        );
        assert_eq!(dispatcher.owner_capacity()[0].available, 0);
        assert!(matches!(
            dispatcher.submit_native_async_on(0, |_| Ok(())),
            Err(InstanceError::QueueFull)
        ));
        let independent = dispatcher.submit_native_async_on(1, |session| {
            let input = session.string("independent-context")?;
            let output = session.call(&input)?;
            session.copy_string(&output)
        })?;
        assert_eq!(
            independent.wait_completed(Duration::from_secs(5)).await?.0,
            "independent-context"
        );
        release.send(()).map_err(|_| InstanceError::Closed)?;
        assert_eq!(
            observed.await?.0,
            "original-envelope:ctx-A:epoch-1:attempt-0"
        );
        Ok::<(), InstanceError>(())
    });
    // Always observe native shutdown before propagating the directed outcome.
    let shutdown = pool.shutdown(Duration::from_secs(10));
    result?;
    assert_eq!(shutdown.joined, 2);
    assert_eq!(shutdown.pending, 0);
    assert_eq!(shutdown.panicked, 0);
    assert!(shutdown.owners.iter().all(|owner| owner.status == 0
        && owner.roots_before_cleanup == 0
        && owner.native_cleanup_attempted));
    println!(
        "RUST-SCHEME owners=2 timeout=observation credit=retained independent=completed roots=0 joined=2"
    );
    println!("OK");
    Ok(())
}
