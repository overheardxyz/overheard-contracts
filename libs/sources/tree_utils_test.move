#[test_only]
module libs::tree_utils_test {
    use libs::types;
    use libs::tree_utils::sha256Note;
    use std::debug::print;

    #[test]
    fun sha256_note_test() {
        let note = types::create_encoded_note(0x1,0x1,0x1,0x1,0x1,0x1);
        let res= sha256Note(note);
        print(&res);
    }
}
