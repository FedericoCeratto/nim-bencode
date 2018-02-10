# Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3 License, see LICENSE file
#
## bencode library - unit tests

import unittest
import tables
import json

import bencode

when defined(coverage):
  import coverage

  template cover(name: expr, body: stmt): stmt {.immediate, dirty.} =
    test name:
      body
    echo "BY FILE: ", coveragePercentageByFile()

suite "bencode":

  test "decode and encode back":

    const test_vector = [
      "0:",
      "d1:a1:b1:c1:d1:k1:ve",
      "d3:bar4:spam3:fooi42ee",
      "d3:cow3:moo4:spam4:eggse",
      "d3:oned3:twod3:bye3:bye2:hii3eeee",
      "de",
      "i3e",
      "le",
      "ll4:nyanee",
    ]
    for testb in test_vector:
      let o = bdecode(testb)
      var e = "error"
      try:
        e = o.bencode
        check e == testb
      except:
        echo ""
        echo "original: ", testb
        echo "decoded:"
        pprint(o)
        echo "encoded again: ", e


  test "decode":

    check bdecode("4:nyan").strVal == "nyan"
    check bdecode("i19e").intVal == 19
    check bdecode("lll4:nyaneee").listVal[0].listVal[0].listVal[0].strVal == "nyan"

    check 99.bencode.bdecode.intVal == 99
    check "99".bencode.bdecode.strVal == "99"


    let vv = {"id":"abcdefghij0123456789"}.bencode
    check vv == "d2:id20:abcdefghij0123456789e"

    let ny = BEDict({
      "EXT": BEDict({
        "A": BEString("B"),
      }.toTable),
    }.toTable)
    check ny.bencode() == "d3:EXTd1:A1:Bee"


  test "decode long string":

    let e = "d1:ad2:id20:abcdefghij01234567896:target20:mnopqrstuvwxyz123456e1:q9:find_node1:t2:aa1:y1:qe"
    let decoded = e.bdecode()
    check decoded.dictVal["t"].strVal == "aa"
    check decoded.dictVal["y"].strVal == "q"
    check decoded.dictVal["q"].strVal == "find_node"
    check decoded.dictVal["a"].dictVal["id"].strVal == "abcdefghij0123456789"


  test "json encoding":

    var
      j: JsonNode
      e: string

    j = %* {
        "EXT": {"A": "B"},
    }
    e = j.bencode
    check e == "d3:EXTd1:A1:Bee"

    j = %* {
      "t":"aa", "y":"q", "q":"ping", "a": {
        "id":"abcdefghij0123456789"
      }
    }
    e = j.bencode
    check e == "d1:ad2:id20:abcdefghij0123456789e1:q4:ping1:t2:aa1:y1:qe"

    j = %* {"t":"aa", "y":"q", "q":"find_node", "a": {"id":"abcdefghij0123456789", "target":"mnopqrstuvwxyz123456"}}
    e = j.bencode
    check e == "d1:ad2:id20:abcdefghij01234567896:target20:mnopqrstuvwxyz123456e1:q9:find_node1:t2:aa1:y1:qe"

    j = %* {"t":"aa", "y":"r", "r": {"id":"0123456789abcdefghij", "nodes": "def456..."}}
    check j.bencode == "d1:rd2:id20:0123456789abcdefghij5:nodes9:def456...e1:t2:aa1:y1:re"

    j = %* {"t":"aa", "y":"q", "q":"get_peers", "a": {"id":"abcdefghij0123456789", "info_hash":"mnopqrstuvwxyz123456"}}
    check j.bencode == "d1:ad2:id20:abcdefghij01234567899:info_hash20:mnopqrstuvwxyz123456e1:q9:get_peers1:t2:aa1:y1:qe"

    j = %* {"t":"aa", "y":"r", "r": {"id":"abcdefghij0123456789", "token":"aoeusnth", "values": ["axje.u", "idhtnm"]}}
    check j.bencode == "d1:rd2:id20:abcdefghij01234567895:token8:aoeusnth6:valuesl6:axje.u6:idhtnmee1:t2:aa1:y1:re"

    let se = @["a", "b", "c"]
    check se.bencode == "l1:a1:b1:ce"


  test "simple encoding":

    check bencode(33) == "i33e"
    check bencode("777") == "3:777"
    check bencode("") == "0:"
    check bencode({"bar": "spam", "foo": "42"}.toTable) == "d3:bar4:spam3:foo2:42e"

    check bencode(
      {"t":"aa", "y":"q", "q":"find_node", "a":
        {"id":"abcdefghij0123456789", "target":"mnopqrstuvwxyz123456"}.toTable().bencode()
      }.toTable
    ) == "d1:a60:d2:id20:abcdefghij01234567896:target20:mnopqrstuvwxyz123456e1:q9:find_node1:t2:aa1:y1:qe"


when defined(coverage):
  echo "BY FILE: ", coveragePercentageByFile()
  echo "TOTAL: ", totalCoverage()
