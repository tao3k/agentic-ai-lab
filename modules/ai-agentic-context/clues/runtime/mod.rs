//! Public clue-exchange owner boundary.
mod cells;
mod deferred;
mod exchange;
mod family;
mod hypotheses;
mod projection;
mod request;
mod slices;
pub use cells::clue_sexpr;
use cells::{data_rows, invalid, rows};
pub use exchange::{ClueExchange, ClueProjection, ClueSelector};
use exchange::{RULES, evaluate};
pub use request::read_clue_request;
