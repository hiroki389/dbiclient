use encoding_rs::Encoding;

/// 指定エンコーディングのバイト列を UTF-8 文字列にデコード
pub fn decode_to_utf8(bytes: &[u8], encoding_label: &str) -> String {
    let enc = Encoding::for_label(encoding_label.as_bytes())
        .unwrap_or(encoding_rs::UTF_8);
    let (cow, _, _) = enc.decode(bytes);
    cow.into_owned()
}

/// Perl の ulength 相当:
/// - 非 ASCII (UTF-8 マルチバイト) → 2
/// - タブ → 4
/// - 制御文字 → 2
/// - その他 → 1
pub fn ulength(s: &str) -> usize {
    let mut size = 0usize;
    for c in s.chars() {
        if c.len_utf8() > 1 {
            size += 2;
        } else if c == '\t' {
            size += 4;
        } else if c.is_control() {
            size += 2;
        } else {
            size += 1;
        }
    }
    size
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_ulength() {
        assert_eq!(ulength("abc"), 3);
        assert_eq!(ulength("あ"), 2);   // CJK
        assert_eq!(ulength("\t"), 4);
        assert_eq!(ulength("\x01"), 2); // control
    }
}
