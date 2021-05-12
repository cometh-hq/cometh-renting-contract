async function assertRevertWith(promise, expectedError) {
  try {
    await promise;
    assert.fail('did not fail');
  } catch (e) {
    assert.match(e.message, new RegExp(expectedError));
  }
}
module.exports = {
  assertRevertWith
};
