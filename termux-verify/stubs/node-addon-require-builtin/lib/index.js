"use strict";
// Pure-JavaScript replacement for node-addon-require-builtin@0.1.x, used ONLY on
// Android/Termux, where the package publishes no native binding for android-arm64
// (dsh then fails at boot with "No usable native binding found ...").
//
// The original addon only forwards requireBuiltin(id) to Node's builtin loader so
// that dsh can reach internal modules such as "internal/modules/cjs/loader".
// Plain require() reaches the same modules when Node runs with --expose-internals,
// which the dsh launcher already uses on Termux (see install.sh step 7).
// The API surface is kept identical so dsh-app-boot does not change.

function requireBuiltin(moduleId) {
  return require(moduleId);
}

function isAllowedInternalId(_moduleId) {
  // Same as the unrestricted upstream variant.
  return true;
}

function getBindingInfo() {
  return {
    backend: "js-stub",
    platform: process.platform,
    arch: process.arch,
    abi: process.versions.modules,
    note: "termux-verify stub: no native binding on android-arm64",
  };
}

exports.requireBuiltin = requireBuiltin;
exports.isAllowedInternalId = isAllowedInternalId;
exports.getBindingInfo = getBindingInfo;
exports.default = {
  requireBuiltin,
  isAllowedInternalId,
  getBindingInfo,
};
