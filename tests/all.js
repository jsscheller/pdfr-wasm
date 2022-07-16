const assert = require("assert");
const path = require("path");
const fs = require("fs/promises");
const Module = require("../dist/pdfr");

before(async function () {
  await fs.mkdir(path.join(__dirname, "out"), { recursive: true });
});

describe("render", function () {
  it("should render pdf to jpeg", async function () {
    const mod = await createModule();
    await mod.callMain(["render", "--pages=1", "--size=100", "assets/sample.pdf", "out"]);
    const exitStatus = mod.exitStatus();
    assert.equal(exitStatus, 0);
  });

  it("should exit properly", async function () {
    const mod = await createModule();
    await mod.callMain(["unknown-subcommand"]);
    const exitStatus = mod.exitStatus();
    assert.equal(exitStatus, 1);
  });
});

async function createModule() {
  const mod = await Module();
  const working = "/working";
  mod.FS.mkdir(working);
  mod.FS.mount(mod.NODEFS, { root: __dirname }, working);
  mod.FS.chdir(working);
  return mod;
}
