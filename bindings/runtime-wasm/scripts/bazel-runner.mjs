// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import { execFileSync } from "node:child_process";

const fallbackExecutables = ["bazelisk", "bazel"];

function execute(executable, args, cwd, env, stdio) {
  return execFileSync(executable, args, {
    cwd,
    env,
    encoding: "utf8",
    stdio,
  }).trim();
}

export function runBazel(
  args,
  {
    cwd,
    env = process.env,
    executables = fallbackExecutables,
    executor = execute,
    stdio = ["ignore", "pipe", "inherit"],
  } = {},
) {
  // npm prepends package-local executable directories. Keep Bazel's declared
  // toolchain environment identical to the preceding dependency build.
  const bazelEnv = env.AGENTIC_AI_LAB_BAZEL_PATH === undefined
    ? env
    : { ...env, PATH: env.AGENTIC_AI_LAB_BAZEL_PATH };
  const configuredBazel = env.BAZEL;
  if (configuredBazel !== undefined) {
    const executable = configuredBazel.trim();
    if (executable === "") {
      throw new Error("BAZEL must name a non-empty executable");
    }
    try {
      return executor(executable, args, cwd, bazelEnv, stdio);
    } catch (error) {
      if (error?.code === "ENOENT" || error?.code === "EACCES") {
        throw new Error(
          `Configured BAZEL executable is unavailable: ${configuredBazel}`,
          { cause: error },
        );
      }
      throw error;
    }
  }

  const missing = [];
  for (const executable of executables) {
    try {
      return executor(executable, args, cwd, bazelEnv, stdio);
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      missing.push(executable);
    }
  }
  throw new Error(`Unable to find Bazel executable; tried ${missing.join(", ")}`);
}
