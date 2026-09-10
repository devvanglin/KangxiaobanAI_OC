package security

import "testing"

func TestEncryptDecrypt(t *testing.T) {
	encoded, err := Encrypt("test-secret", "api-key-value")
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if encoded == "api-key-value" || encoded == "" {
		t.Fatalf("secret was not encrypted: %q", encoded)
	}
	decoded, err := Decrypt("test-secret", encoded)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	if decoded != "api-key-value" {
		t.Fatalf("decoded=%q", decoded)
	}
	if _, err := Decrypt("wrong-secret", encoded); err == nil {
		t.Fatal("wrong key unexpectedly decrypted secret")
	}
}
