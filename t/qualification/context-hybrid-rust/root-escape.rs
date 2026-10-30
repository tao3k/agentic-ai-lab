// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Must fail compilation: only owned projections may leave a fixed native VM.
fn escape(dispatcher: &gerbil_scheme::instances::InstanceDispatcher) {
    let _ = dispatcher.submit_native_on(0, |session| session.string("forbidden-root"));
}
fn main() {}
