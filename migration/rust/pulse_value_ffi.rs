#![allow(dead_code)]

#[path = "../../dist/pulse-rust/dns/migration_pulseshellboundaryvalue.rs"]
mod migration_pulseshellboundaryvalue;

use migration_pulseshellboundaryvalue as pilot;

pub const DNS_PULSE_PHASE_READING: u32 = 0;
pub const DNS_PULSE_PHASE_PROCESSING: u32 = 1;
pub const DNS_PULSE_PHASE_CLOSED: u32 = 2;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct DnsPulseStreamState {
    pub buffered: u32,
    pub capacity: u32,
    pub phase: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct DnsPulseDispatchResult {
    pub accepted: u8,
    pub next: DnsPulseStreamState,
}

fn to_pilot_phase(phase: u32) -> pilot::shell_phase {
    match phase {
        DNS_PULSE_PHASE_READING => pilot::shell_phase::ValueReading,
        DNS_PULSE_PHASE_PROCESSING => pilot::shell_phase::ValueProcessing,
        _ => pilot::shell_phase::ValueClosed,
    }
}

fn from_pilot_phase(phase: pilot::shell_phase) -> u32 {
    match phase {
        pilot::shell_phase::ValueReading => DNS_PULSE_PHASE_READING,
        pilot::shell_phase::ValueProcessing => DNS_PULSE_PHASE_PROCESSING,
        pilot::shell_phase::ValueClosed => DNS_PULSE_PHASE_CLOSED,
    }
}

fn to_pilot_state(state: DnsPulseStreamState) -> pilot::stream_state {
    pilot::stream_state {
        buffered: state.buffered,
        capacity: state.capacity,
        phase: to_pilot_phase(state.phase),
    }
}

fn from_pilot_state(state: pilot::stream_state) -> DnsPulseStreamState {
    DnsPulseStreamState {
        buffered: state.buffered,
        capacity: state.capacity,
        phase: from_pilot_phase(state.phase),
    }
}

#[no_mangle]
pub extern "C" fn dns_pulse_available(state: DnsPulseStreamState) -> u32 {
    pilot::available(to_pilot_state(state))
}

#[no_mangle]
pub extern "C" fn dns_pulse_accepts_fragment(
    state: DnsPulseStreamState,
    len: u32,
) -> u8 {
    if pilot::accepts_fragment(to_pilot_state(state), len) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn dns_pulse_dispatch_authenticated_bytes(
    state: DnsPulseStreamState,
    len: u32,
) -> DnsPulseDispatchResult {
    let result = pilot::dispatch_authenticated_bytes_value(to_pilot_state(state), len);
    DnsPulseDispatchResult {
        accepted: if result.accepted { 1 } else { 0 },
        next: from_pilot_state(result.next),
    }
}
