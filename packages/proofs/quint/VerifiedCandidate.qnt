// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module VerifiedCandidate {
  // Independent grader validity is assumed; this models artifact admission.
  var source:int
  var grader:int
  var artifactSource:int
  var artifactGrader:int
  var sealed:bool
  action init = all {source'=0,grader'=0,artifactSource'=0,artifactGrader'=0,sealed'=false}
  action edit = all {not(sealed),source'=source+1,grader'=grader,
    artifactSource'=artifactSource,artifactGrader'=artifactGrader,sealed'=false}
  action accept = all {source'=source,grader'=grader,
    artifactSource'=source,artifactGrader'=grader,sealed'=true}
  action newTask = all {source'=source+1,grader'=grader,
    artifactSource'=artifactSource,artifactGrader'=artifactGrader,sealed'=false}
  action replaceGrader = all {source'=source,grader'=grader+1,
    artifactSource'=artifactSource,artifactGrader'=artifactGrader,sealed'=false}
  action step = any {edit,accept,newTask,replaceGrader}
  val BoundCandidate = sealed implies (source == artifactSource and grader == artifactGrader)
}
