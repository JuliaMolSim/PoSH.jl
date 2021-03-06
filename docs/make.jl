


using Documenter, ACE

makedocs(sitename="ACE.jl Documentation",
         pages = [
        "Home" => "index.md",
        "Introduction" => "intro.md",
        "Getting Started" => "gettingstarted.md",
        "Developer Docs" => "devel.md",
        "Pure ACE" => [
            "What is Pure ACE" => "pureintro.md",
            "Pure Basis Recursion" => "purerecursion.md",
            "Products of Polynomials" => "polyproducts.md",
        ]
        ])

deploydocs(
    repo = "github.com/ACEsuit/ACE.jl.git",
    devbranch = "main"
)
