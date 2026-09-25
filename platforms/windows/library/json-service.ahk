;;;; AHK v2 JSON parser - https://github.com/TheArkive/JXON_ahk2

jsonLoad(&src, args*) {
	key := "", isKey := false
	stack := [tree := []]
	next := '"{[01234567890-tfn'
	pos := 0

	while ((ch := SubStr(src, ++pos, 1)) != "") {
		if InStr(" `t`n`r", ch)
			continue
		if !InStr(next, ch, true) {
			testArr := StrSplit(SubStr(src, 1, pos), "`n")

			line := testArr.Length
			col := pos - InStr(src, "`n", , -(StrLen(src) - pos + 1))

			msg := Format("{}: line {} col {} (char {})"
				, (next == "") ? ["Extra data", ch := SubStr(src, pos)][1]
				: (next == "'") ? "Unterminated string starting at"
					: (next == "\") ? "Invalid \escape"
					: (next == ":") ? "Expecting ':' delimiter"
					: (next == '"') ? "Expecting object key enclosed in double quotes"
					: (next == '"}') ? "Expecting object key enclosed in double quotes or object closing '}'"
					: (next == ",}") ? "Expecting ',' delimiter or object closing '}'"
					: (next == ",]") ? "Expecting ',' delimiter or array closing ']'"
					: ["Expecting JSON value(string, number, [true, false, null], object or array)"
						, ch := SubStr(src, pos, (SubStr(src, pos) ~= "[\]\},\s]|$") - 1)][1]
				, line, col, pos)

			throw Error(msg, -1, ch)
		}

		obj := stack[1]
		isArray := (obj is Array)

		if i := InStr("{[", ch) { ; start new object / map?
			val := (i = 1) ? Map() : Array()	; ahk v2

			isArray ? obj.Push(val) : obj[key] := val
			stack.InsertAt(1, val)

			next := '"' ((isKey := (ch == "{")) ? "}" : "{[]0123456789-tfn")
		} else if InStr("}]", ch) {
			stack.RemoveAt(1)
			next := (stack[1] == tree) ? "" : (stack[1] is Array) ? ",]" : ",}"
		} else if InStr(",:", ch) {
			isKey := (!isArray && ch == ",")
			next := isKey ? '"' : '"{[0123456789-tfn'
		} else { ; string | number | true | false | null
			if (ch == '"') { ; string
				i := pos
				while i := InStr(src, '"', , i + 1) {
					val := StrReplace(SubStr(src, pos + 1, i - pos - 1), "\\", "\u005C")
					if (SubStr(val, -1) != "\")
						break
				}
				if !i ? (pos--, next := "'") : 0
					continue

				pos := i ; update pos

				val := StrReplace(val, "\/", "/")
				val := StrReplace(val, '\"', '"')
					, val := StrReplace(val, "\b", "`b")
					, val := StrReplace(val, "\f", "`f")
					, val := StrReplace(val, "\n", "`n")
					, val := StrReplace(val, "\r", "`r")
					, val := StrReplace(val, "\t", "`t")

				i := 0
				while i := InStr(val, "\", , i + 1) {
					if (SubStr(val, i + 1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
						continue 2

					unicodeCodepoint := Abs("0x" . SubStr(val, i + 2, 4)) ; \uXXXX - JSON unicode escape sequence
					if (unicodeCodepoint < 0x100)
						val := SubStr(val, 1, i - 1) . Chr(unicodeCodepoint) . SubStr(val, i + 6)
				}

				if isKey {
					key := val, next := ":"
					continue
				}
			} else { ; number | true | false | null
				val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$", , pos) - pos)

				if IsInteger(val)
					val += 0
				else if IsFloat(val)
					val += 0
				else if (val == "true" || val == "false")
					val := (val == "true")
				else if (val == "null")
					val := ""
				else if isKey {
					pos--, next := "#"
					continue
				}

				pos += i - 1
			}

			isArray ? obj.Push(val) : obj[key] := val
			next := obj == tree ? "" : isArray ? ",]" : ",}"
		}
	}

	return tree[1]
}
