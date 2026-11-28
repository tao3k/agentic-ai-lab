// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
use std::fs::OpenOptions;
use std::io::Write;
use std::time::{Duration, Instant};

#[repr(C)]
struct ResultBuffer {
    status: i32,
    data: *mut u8,
    length: usize,
}

unsafe extern "C" {
    fn agentic_ai_lab_semantic_v1_open() -> i32;
    fn agentic_ai_lab_semantic_v1_close() -> i32;
    fn agentic_ai_lab_semantic_v1_context_command(
        input: *const u8,
        length: usize,
        result: *mut ResultBuffer,
    ) -> i32;
    fn agentic_ai_lab_semantic_v1_result_release(result: *mut ResultBuffer);
}

fn command(fields: &str) -> String {
    let input = format!("(object (\"schema\" \"agentic-ai-lab.agenda-request.v1\") {fields})");
    let mut result = ResultBuffer {
        status: 0,
        data: std::ptr::null_mut(),
        length: 0,
    };
    let status = unsafe {
        agentic_ai_lab_semantic_v1_context_command(input.as_ptr(), input.len(), &mut result)
    };
    let output = if result.data.is_null() {
        String::new()
    } else {
        let bytes = unsafe { std::slice::from_raw_parts(result.data, result.length) };
        String::from_utf8_lossy(bytes).into_owned()
    };
    unsafe { agentic_ai_lab_semantic_v1_result_release(&mut result) };
    assert_eq!(status, 0, "{output}");
    output
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let [_, mode, source, journal, sink] = args.as_slice() else {
        panic!("usage: agenda-native dispatch|recover SOURCE JOURNAL SINK")
    };
    assert_eq!(unsafe { agentic_ai_lab_semantic_v1_open() }, 0);
    let authorized = if mode == "dispatch" {
        "(list \"revoked\" \"done\" \"work\" \"later\")"
    } else {
        "(list \"done\" \"work\" \"later\")"
    };
    let opened = command(&format!(
        "(\"operation\" \"open\") (\"source\" {source:?}) (\"journal\" {journal:?}) \
         (\"offsetMinutes\" 0) (\"action\" \"notify\") (\"authorizedIds\" {authorized})"
    ));
    if mode == "dispatch" {
        assert!(opened.contains("(\"scheduled\" \"revoked\")"), "{opened}");
        let refreshed = command(
            "(\"operation\" \"refresh\") (\"authorizedIds\" (list \"done\" \"work\" \"later\"))",
        );
        assert!(
            refreshed.contains("(\"scheduled\" \"work\")"),
            "{refreshed}"
        );
        let limit = Instant::now() + Duration::from_secs(12);
        let released = loop {
            let result = command("(\"operation\" \"take\")");
            if result.contains("(\"dispatch\" #t)") {
                break result;
            }
            assert!(
                Instant::now() < limit,
                "owner timer did not release work: {result}"
            );
            std::thread::sleep(Duration::from_millis(100));
        };
        assert!(released.contains("(\"identity\" \"work\")"), "{released}");
        assert!(released.contains("(\"action\" \"notify\")"), "{released}");
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(sink)
            .unwrap();
        writeln!(file, "{released}").unwrap();
        file.sync_all().unwrap();
        // Simulate process loss after the external handoff, before any receipt.
        std::process::exit(73);
    }
    assert_eq!(mode, "recover");
    assert!(opened.contains("(\"scheduled\" \"later\")"), "{opened}");
    let result = command("(\"operation\" \"take\")");
    assert!(result.contains("(\"dispatch\" #f)"), "{result}");
    assert_eq!(std::fs::read_to_string(sink).unwrap().lines().count(), 1);
    assert_eq!(unsafe { agentic_ai_lab_semantic_v1_close() }, 0);
    println!("AGENDA-NATIVE-OK selected=work restarted=later dispatches=1");
}
