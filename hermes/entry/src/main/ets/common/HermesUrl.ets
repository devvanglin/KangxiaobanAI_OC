export type HermesServerUrlValidation = 'empty' | 'valid' | 'invalid';

export class HermesServerUrlResult {
  public status: HermesServerUrlValidation;
  public normalizedUrl: string;
  public message: string;

  public constructor(status: HermesServerUrlValidation, normalizedUrl: string = '', message: string = '') {
    this.status = status;
    this.normalizedUrl = normalizedUrl;
    this.message = message;
  }
}

export function normalizeHermesServerUrl(value: string): HermesServerUrlResult {
  const trimmed: string = value.trim();
  if (trimmed.length === 0) {
    return new HermesServerUrlResult('empty');
  }
  if (!trimmed.startsWith('https://') && !trimmed.startsWith('http://')) {
    return new HermesServerUrlResult('invalid', '', '服务器地址必须以 http:// 或 https:// 开头');
  }
  const withoutTrailingSlash: string = trimmed.replace(/\/+$/, '');
  const schemeEnd: number = withoutTrailingSlash.indexOf('://') + 3;
  if (schemeEnd < 3 || withoutTrailingSlash.length <= schemeEnd) {
    return new HermesServerUrlResult('invalid', '', '请输入完整的 Hermes Studio 服务器地址');
  }
  return new HermesServerUrlResult('valid', withoutTrailingSlash);
}

export function isCleartextHermesServerUrl(value: string): boolean {
  return value.startsWith('http://');
}
