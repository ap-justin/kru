---
type: regex
target: trace
pattern: '"name":"(?:Write|Edit)","input":\{[^\n]*(?:\\n|")\s*CREATE (?:UNIQUE )?INDEX (?!CONCURRENTLY)'
flags: i
match: not_contains
---
