## Emerald

A for-fun programming language with mechanics I like. For example:

- [x] While loops with else-while clauses
- [x] Access array elements by number `array.1.0.8` instead of subscript `array[1][0][8]`
- [x] Use `./` to access self
- [x] Composition over inheritance
- [x] Functions and types are first-class and can be passed around
- [x] Built-in arrays, tuples, dictionaries, and ranges
- [x] Identifier naming conventions enforced at the language level
- Capitalized identifiers are types
- lowercase identifiers are variables and functions
- UPPERCASE identifiers are constants

---

- [Code Examples](#code-examples)
- [Documentation](#documentation)
- [Getting Started](#getting-started)
- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
- [Running Your Own Programs](#running-your-own-programs)
- [License](#license)

---

## Code Examples

### Types

```
Number {
	numerator = nil

	new { num;
		./numerator = num
	}
}

Number(4).numerator `== 4
```

### Functions

```
fizz_buzz { n;
	if n % 3 == 0 and n % 5 == 0
		'FizzBuzz'
	elif n % 3 == 0
		'Fizz'
	elif n % 5 == 0
		'Buzz'
	else
		'|n|'
	end
}

result = []
1..15.each {;
	result << fizz_buzz(it)
}
result.0  `"1"
result.2  `"Fizz"
result.14 `"FizzBuzz"
```

### Variables

```
Repo {
	user;
	name;
	
	new { user, name;
		./name = name
	}
	
	to_s {;
		"|user|/|name|"
	}
}
repo = Repo('figgleforth', 'programming-language')
NAME = repo.to_s()
```

## Documentation

For comprehensive syntax examples and language features, see these test files:

- [Lexer Tests](./tests/lexer_test.rb) - Tokenization
- [Parser Tests](./tests/parser_test.rb) - Syntax parsing
- [Interpreter Tests](./tests/interpreter_test.rb) - Language semantics and execution
- [Example Tests](./tests/examples_test.rb) - Small example programs

## Getting Started

### Prerequisites

- Ruby 3.4.1 or higher
- Bundler

```shell script
$ git clone https://github.com/figgleforth/emerald.git
$ cd emerald
$ bundle install
```

### Running Tests

```shell script
$ bundle exec rake test
```

### Running Your Own Programs

```shell script
$ bundle exec rake interp[./your_source.e]
```

## License

This project is licensed under the MIT License, see the [license.md](./license.md) file for details.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()
