module {
    // Validate token name (e.g., non-empty, max length)
    public func isValidTokenName(name: Text): Bool {
        name.size() > 0 and name.size() <= 50
    };

    // Validate token symbol (e.g., non-empty, max length 5)
    public func isValidTokenSymbol(symbol: Text): Bool {
        symbol.size() > 0 and symbol.size() <= 5
    };

    // Validate total supply (e.g., must be greater than 0)
    public func isValidTotalSupply(totalSupply: Nat): Bool {
        totalSupply > 0
    };

    // Validate decimals (e.g., between 0 and 18)
    public func isValidDecimals(decimals: Nat): Bool {
        decimals >= 0 and decimals <= 18
    };

    // General validation for all token attributes
    public func validateTokenAttributes(
        name: Text,
        symbol: Text,
        totalSupply: Nat,
        decimals: Nat
    ): Bool {
        isValidTokenName(name) and isValidTokenSymbol(symbol) and
        isValidTotalSupply(totalSupply) and isValidDecimals(decimals)
    };

    // Validate Principal (e.g., ensure not null and matches some criteria)
    public func isValidPrincipal(principal: ?Principal): Bool {
        switch (principal) {
            case null { false };
            case (?_) { true };
        }
    };

    // Validate token ID (e.g., greater than 0)
    public func isValidTokenId(tokenId: Nat): Bool {
        tokenId > 0
    };
};