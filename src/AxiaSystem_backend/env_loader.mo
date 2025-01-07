import Text "mo:base/Text";
import Option "mo:base/Option";
import Trie "mo:base/Trie";

module {
    private var env: Trie.Trie<Text, Text> = Trie.empty();

   public func loadEnv(envContent: Text) {
    env := Text.split(envContent, "\n")
        .vals()
        .filter(func(line) { not Text.startsWith(line, "#") and Text.contains(line, "=") })
        .foldLeft(env, func(trie, line) {
            let parts = Text.split(line, "=").toArray();
            switch (parts.size()) {
                case 2 { 
                    Trie.put(trie, keyOf(Text.trim(parts[0])), Text.equal, Text.trim(parts[1])).0;
                };
                case _ { trie };
            }
        });
};

    public func get(key: Text): ?Text {
        Trie.find(env, key)
    };

    public func getPrincipal(key: Text): ?Principal {
        switch (get(key)) {
            case (?value) { Option.from(Principal.fromText(value)) };
            case null { null };
        }
    };
};