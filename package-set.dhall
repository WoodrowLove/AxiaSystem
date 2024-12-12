let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.13.5-20241206/package-set.dhall sha256:1697706e888f5bcdb7681aedd002d2d59c102049794654a6af8b3815bc15fb97

let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let additions =
    [{ name = "matchers"
     , repo = "https://github.com/kritzcreek/motoko-matchers"
     , version = "v1.3.0"
     , dependencies = [] : List Text
     }] : List Package

let overrides =
    [] : List Package

in  upstream # additions # overrides
