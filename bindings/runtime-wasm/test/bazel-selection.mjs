// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import assert from "node:assert/strict";

import { runBazel } from "../scripts/bazel-runner.mjs";

const cwd = new URL("..", import.meta.url);
const missing = (code = "ENOENT") => {
  const error = new Error(code);
  error.code = code;
  return error;
};

function expectConfigurationFailure(bazel, diagnostic, executor) {
  assert.throws(
    () =>
      runBazel(["build", "//selection:test"], {
        cwd,
        env: { ...process.env, BAZEL: bazel },
        executor,
        stdio: ["ignore", "pipe", "pipe"],
      }),
    diagnostic,
  );
}

expectConfigurationFailure(" \t", /BAZEL must name a non-empty executable/);
expectConfigurationFailure(
  "missing-bazel",
  /Configured BAZEL executable is unavailable/,
  () => {
    throw missing();
  },
);
expectConfigurationFailure(
  "non-executable-bazel",
  /Configured BAZEL executable is unavailable/,
  () => {
    throw missing("EACCES");
  },
);

const configuredCalls = [];
assert.equal(
  runBazel(["info", "bazel-bin"], {
    cwd,
    env: { ...process.env, BAZEL: "configured-bazel" },
    executor: (executable, args) => {
      configuredCalls.push([executable, args]);
      return "/configured/bazel-bin";
    },
  }),
  "/configured/bazel-bin",
);
assert.deepEqual(configuredCalls, [
  ["configured-bazel", ["info", "bazel-bin"]],
]);

const precedenceCalls = [];
assert.equal(
  runBazel(["build", "//selection:test"], {
    cwd,
    env: {},
    executables: ["bazelisk", "bazel"],
    executor: (executable) => {
      precedenceCalls.push(executable);
      return "ok";
    },
  }),
  "ok",
);
assert.deepEqual(precedenceCalls, ["bazelisk"]);

const fallbackCalls = [];
assert.equal(
  runBazel(["build", "//selection:test"], {
    cwd,
    env: {},
    executables: ["bazelisk", "bazel"],
    executor: (executable) => {
      fallbackCalls.push(executable);
      if (executable === "bazelisk") throw missing();
      return "ok";
    },
  }),
  "ok",
);
assert.deepEqual(fallbackCalls, ["bazelisk", "bazel"]);

// Nested npm scripts must not invalidate the already-built Gerbil toolchain.
for (const configured of [false, true]) {
  const npmEnv = {
    PATH: "/package/node_modules/.bin:/sdk/bin:/usr/bin",
    POO_FLOW_BAZEL_PATH: "/sdk/bin:/usr/bin",
    GERBIL_NATIVE_ABI: "source-bound-abi",
    ...(configured ? { BAZEL: "configured-bazel" } : {}),
  };
  runBazel(["build", "//selection:test"], {
    cwd,
    env: npmEnv,
    executor: (_executable, _args, _cwd, childEnv) => {
      assert.equal(childEnv.PATH, "/sdk/bin:/usr/bin");
      assert.equal(childEnv.GERBIL_NATIVE_ABI, "source-bound-abi");
      return "ok";
    },
  });
  assert.equal(npmEnv.PATH, "/package/node_modules/.bin:/sdk/bin:/usr/bin");
}

runBazel(["info", "bazel-bin"], {
  cwd,
  env: { PATH: "/user/tools:/usr/bin" },
  executor: (_executable, _args, _cwd, childEnv) => {
    assert.equal(childEnv.PATH, "/user/tools:/usr/bin");
    return "ok";
  },
});

assert.throws(
  () =>
    runBazel(["build", "//selection:test"], {
      cwd,
      env: {},
      executables: ["bazelisk", "bazel"],
      executor: () => {
        throw missing();
      },
    }),
  /Unable to find Bazel executable; tried bazelisk, bazel/,
);
