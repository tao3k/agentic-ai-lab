// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module AccountingAbstraction {
  // Signs and snapshot order are the observations used by Safety. Negative
  // counters and snapshots after current cost remain represented and rejected.
  // The sets overapproximate addition from negative/after states, rather than
  // imposing a trace cutoff or disabling repeated actions.
  def addSign(sign: str, tokens: int): Set[str] =
    if (tokens == 0) Set(sign)
    else if (sign == "negative") Set("negative", "zero", "positive")
    else Set("positive")
  def advanceSnapshot(order: str, tokens: int): Set[str] =
    if (tokens == 0 or order == "unset" or order == "before") Set(order)
    else if (order == "equal") Set("before")
    else Set("before", "equal", "after")
}
