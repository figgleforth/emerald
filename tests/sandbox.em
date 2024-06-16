Atom {
	& Entity
	~ Transform
	& CHARACTER

	xyz += 1
}


Atom {
	& Pos
	~ Rot

	whatever =;
}

Player > Atom {
	& Transform # & will merge Transform into this object, it merges all its members and functions, including the ones that were merged into it beforehand
#	& Transform as transform
	~ Transform

	number = -1
	player = 69 + 12 / -123 * 4 % 6
	whatever =;

	character = CHARACTER.GUY

	& CHARACTER
	character = GUY
}

Sokoban {
	CHARACTER {
		GUY
		PLATFORM
	}
}

Entity {
	character =;
	name =;
	position =;

	# class var
	self.references.count = 0

	# class func
	self.do_something {}

	self.inspect { "Entity(`self.refs`)" }
}


player./current_level = 1 # ./ is like  &. in Ruby. I want the dot to go first since that feels more like accessing a member or whatever. the / is just the next key on the keyboard so it flows. I want this language to feel as smooth as possible.

if player./current_level # also works like ruby's #respond_to?
}

nice { param, param_with_default = 1 -> "body" }

cool { param, param_with_default = 1 ->
	"body"
}

spicy = {
	input = 69 -> 'whatever'
}

sixty_nine = { 69 + 12 / -123 * 4 % 6 }

func_without_params {
	"body!"
}

empty {}
Empty {}

lost = { in = 42 -> }

{
	whatever
}

GAME_LOOP_STATE {
	UPDATE = 0
	RENDER = 69 + 12 / -123 * 4 % 6
	WHENCE = 'yes' # todo: need to .expressions[0]
}

TESTING {}

(a + b) * c
!a
-a + +b
a ** b
a * b / c % d
a + b - c
a << b >> c
a < b <= c > d >= e
a == b != c === d !== e
a & b
a ^ b
a | b
a && b
a || b
a = b
a += b
a -= b
a *= b
a /= b
a %= b
a &= b
a |= b
a ^= b
a <<= b
a >>= b
a, b, c
player = 69 + 12 / -123 * 4 % 6
a.b.c = 0
1 ----------- 2
1 +++++++ 2
1 - --2
1 & 1
#a ? b : c # todo


next_level { player
# todo: unhandled +=
#	player.level += 1
}



# adds members of this object to the local scope but they reference the arg player. allows you to do:
gain_level { player ->
#	& player
#	& works.on.nested.too # todo: this parsed as `exprs(1): ["BE(BE(BE(&works . ident(on)) . ident(nested)) . ident(too))`
#	level += 1 # equivalent to player.level when not using &. it's the programmer's responsibility to make sure they don't & args with clashing members. #raise when that happens
}

#more { &one, &two = 2, three = 3 -> # todo: the & in params isn't treated as a comp technically, but the interpreter can figure it out
#}

STATUS {
   WORKING_ON_IT = 1
   NOT_WORKING_ON_IT
}

Emerald {
   version = 0.0
   bugs = 1_000_000
   status = STATUS.WORKING_ON_IT

   info {
      "Emerald version `version`"
   }

   increase_version { to ->
      version = to
   }

   change_version { by delta ->
#      version += delta
   }
}

first./middle./last

_SOME_ENUM {}

# todo: abc ?? xyz # abc if abc, otherwise xyz

SOME_CONST = 1

_Emerald {
	& Atom # this should merge the two scopes but also allow prefixing the scope with atom.
}

_function {
	& Atom
	 _ANOTHER_ENUM = 5
	_ANOTHER_ENUM {}
}

#_ANOTHER_ENUM = 'yet'

COLLECTION {
	ONE, TWO = 2
	THREE {
		FOUR = 4, FIVE {
			ZERO = 0
		}, SIX {}
	},
	SEVEN = Atom.new
}

COLLECTION.THREE.FIVE

Transform {
	position =;
}

Entity {
	~ Transform
}

Lilly_Pad {
#	& Entity

	speed = 1.0

	inspect { "Lilly(at: `position`, speed: `speed` units" } # position directly accessible because it was merged into this object with the &Entity statement
}

this? = :test


Enum_Collection_Expr {
	& Ast_Expression

	name =;
	constants =;

	to_s {
#		if short_form
#			"enum{`name`, constants(`constants.count`)}"
#		else
#			"enum{`name`, constants(`constants.count`): `constants.map(:to_s)`}"
#		}
	}
}


if 1 > 2
	aaa
	bbb
elsif 4 > 3
	ccc
elif 5 > 3
	ddd
	eee
	fff
ef 100_000
	hhh
else
	ggg
}

Shop > Entity {
	~ Physics
}

Audio_Player {
	& Entity
	~ Inventory
	~ Physics
	~ Renderer
	~ Rotation
}

Entity > Object {
#	& Inventory
#	& Physics

	name =;
	move_speed =;

	go { to position ->
		inventory.position = position
	}
}

go(to: 123)

method {}
method2 { 48 }
method3 { input -> "`input`" }
method4 { in1, in2, in3, in4, in5 -> "boo!" }
method5 { on input -> "`input`" }

method
method2()
method3('yay')
method4(4 + 8, Abc {}, WHAT {}, whatever {}, 32)
method5(on: 'bwah')
imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, member: shit)


if 1 > 2
	aaa
	bbb
elif 4 > 3
	ccc
elif 5 > 3
	ddd
	eee
	fff
elif 100_000
	hhh
else
	ggg
}

while 4 > 3
	skip
	stop, skip, whatever
	1 + 2
	go!(48), yay
}

while a > 0
	# ...
elswhile a < 0
	# ...
else
	# ...
}

while true
}, while false
}, while
	shit
}

a[b[c]][1][abc[2 + 3]] + 4

a[b[c]][1][abc[2+3]+4]

a[1+2][b[c[3]]][d+e][f-g]
a[1+2][b[c[3]]][d+e][f-g]

[1, 2, 3+4,while true
}, while false
}, while
	shit
}, Abc{}, DEF{}, def{}, {}, [], a[0], Player > Atom {
	~ Transform # & will merge Transform into this object, it merges all its members and functions, including the ones that were merged into it beforehand
#	& Transform as transform # this is currently parsing as a variable assignment
	number = -1
	player = 69 + 12 / -123 * 4 % 6
	whatever =;

	character = CHARACTER.GUY
}]



a[1+2][b[c[3]]][d+e][f-g]

some_var[]

[]

wtf =;
go(wtf =;)

### omg this should do this at runtime! aaaaah this is amazing so it does this on the scope it's called on
shop & physics


Danger {
	it =;
}

it = true

~ Danger
it # this would fail, because you removed it earlier

###


#& physics
#~ position


Atom {
	& Entity
	& Transform
}

[[]]

Record {
	& Columns
	& Querying
	& Persistence
	& Validations
}

Readonly_Record { # equivalent of only & Columns
	& Record
	~ Persistence
	~ Validations
}

Readonly > Record {
	& Querying
	& Columns
	~ Persistence
	~ Validations
}

records = Record.where { it.something == true }
records = Readonly.where { it.something == true } # lighter objects in memory because they aren't using Persistence and Validations

test { abc &this = 1, def that, like = 2, &whatever  ->
}

test { with &a = 1, whence b = 2, c, d = variable= 1 ->
	# params with & are going to have their variables and functions merged into this scope
}

[1, "asdf"]


1.0
1.
0.1
.1

1.2.3.4
