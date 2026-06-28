import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

export default function testsuite() {
  describe('localUnitTest', () => {
    beforeAll(() => {
      // 测试套件开始前的准备工作
    });
    beforeEach(() => {
      // 每个测试用例开始前的准备工作
    });
    afterEach(() => {
      // 每个测试用例结束后的清理工作
    });
    afterAll(() => {
      // 测试套件结束后的清理工作
    });

    it('assertContain', 0, () => {
      let a = 'abc';
      let b = 'b';
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('assertEqual', 0, () => {
      let a = 1;
      let b = 1;
      expect(a).assertEqual(b);
    });

    it('assertTrue', 0, () => {
      let a = true;
      expect(a).assertTrue();
    });

    it('assertFalse', 0, () => {
      let a = false;
      expect(a).assertFalse();
    });
  });
}