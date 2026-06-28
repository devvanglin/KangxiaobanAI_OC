import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import localUnitTest from './LocalUnit.test';

export default function listTest() {
  describe('listTest', () => {
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
    });

    it('testNumberEqual', 0, () => {
      let a = 1;
      let b = 1;
      expect(a).assertEqual(b);
    });

    it('testStringEqual', 0, () => {
      let a = 'DanmakuPlayer';
      let b = 'DanmakuPlayer';
      expect(a).assertEqual(b);
    });

    it('testBooleanEqual', 0, () => {
      let a = true;
      let b = true;
      expect(a).assertEqual(b);
    });

    it('testArrayEqual', 0, () => {
      let a = [1, 2, 3];
      let b = [1, 2, 3];
      expect(a).assertEqual(b);
    });
  });
}