# Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3 License, see LICENSE file
#
## bencode library

from algorithm import sorted, sort
from json import JsonNodeKind, JsonNode
from lexbase import BaseLexer
import hashes
import json
import os
import strutils
import tables

when defined(coverage):
  import coverage
  # FIXME
  {.push cov.}

type
  BENodeKind* = enum
    tkEof,
    tkInt,
    tkBytes,
    tkList,
    tkDict

  BENode* = object
    case kind: BENodeKind
    of tkInt: intVal*: int
    of tkBytes: strVal*: string
    of tkList: listVal*: seq[BENode]
    of tkDict: dictVal*: Table[string, BENode]
    else:
      discard

  BEncodeParser* = object of BaseLexer

  BEDecoded = tuple[obj: BENode, remaining: string]


proc pprint*(self: BENode, indent=0, hex=false): void =
  ## Pretty-print BENode tree
  case self.kind:
  of tkInt:
    echo repeat(' ', indent) & $self.intVal
  of tkBytes:
    var line = repeat(' ', indent)
    if hex and self.strVal.len > 12:  # FIXME
      for c in self.strVal:
        line.add c.int.toHex(2)
    else:
      line.add self.strVal

    echo line

  of tkList:
    echo repeat(' ', indent) & "["
    for item in self.listVal:
      pprint(item, indent + 1, hex=hex)
    echo repeat(' ', indent) & "]"

  of tkDict:
    echo repeat(' ', indent) & "{"
    for k, v in self.dictVal.pairs(): #TODO sort
      echo repeat(' ', indent + 1) & k
      pprint(v, indent + 2, hex=hex)

    echo repeat(' ', indent) & "}"

  of tkEof:
    echo repeat(' ', indent) & "END"

proc bdec(s: string): BEDecoded  =
  if len(s) == 0:
    return (BENode(kind: tkEof), "")

  if s[0] == 'i':  # integer
    let e_pos = s.find('e')
    let remaining = s[(e_pos+1)..<len(s)]
    return (BENode(kind: tkInt, intVal: s[1..<e_pos].parseInt), remaining)

  if s[0] == 'd':  # dict
    var d = BENode(kind: tkDict, dictVal: initTable[string, BENode]())
    var remaining = s[1..<len(s)]
    while len(remaining) != 0 and remaining[0] != 'e':
      var decoded = bdec(remaining)
      if decoded.obj.kind != tkBytes:
        echo "error"
        return (BENode(kind: tkEof), s)

      remaining = decoded.remaining
      let dict_key = decoded.obj.strVal

      decoded = bdec(remaining)
      remaining = decoded.remaining
      let dict_val = decoded.obj

      d.dictVal[dict_key] = dict_val

    remaining = remaining[1..<len(remaining)]  # trim the "e"
    return (d, remaining)

  if s[0] == 'l':  # list
    var list = BENode(kind: tkList, listVal: @[])
    var remaining = s[1..<len(s)]

    while len(remaining) != 0 and remaining[0] != 'e':
      var decoded = bdec(remaining)
      list.listVal.add decoded.obj
      remaining = decoded.remaining

    return (list, remaining)

  # assume it is a byte string
  let colon_pos = s.find(':')
  if colon_pos == -1:
    return (BENode(kind: tkEof), s)

  var bytes_len: int
  try:
    bytes_len = s[0..<colon_pos].parseInt
  except:
    return (BENode(kind: tkEof), s)

  let bytes_string = s[(colon_pos+1)..(colon_pos+bytes_len)]
  let remaining = s[(colon_pos + bytes_len + 1)..<len(s)]
  return (BENode(kind: tkBytes, strVal: bytes_string), remaining)


proc bdecode*(s: string): BENode  =
  ## Decode string into BENode tree
  return bdec(s).obj


proc bencode*(self: BENode): string


proc bencode*(i: int): string =
  ## Encode int
  "i$#e" % $i

proc bencode*(s: string): string =
  ## Encode string
  "$#:$#" % [$len(s), s]

proc bencode*(sequence: seq[int]): string =
  ## Encode sequence of ints
  result = "l"
  for item in sequence:
    result.add bencode(item)
  result.add("e")

proc bencode*(sequence: seq[string]): string =
  ## Encode sequence of strings
  result = "l"
  for item in sequence:
    result.add bencode(item)
  result.add("e")

proc bencode*(t: Table): string =
  ## Encode table
  result = "d"
  var keys: seq[string] = @[]
  for k in t.keys():
    keys.add k

  keys.sort(proc (x,y: string): int = cmp(x, y))

  for k in keys:
    result.add bencode(k)
    result.add bencode(t[k])
  result.add("e")

proc bencode*(sequence: seq[BENode]): string =
  ## Encode sequence of BENode
  result = "l"
  for item in sequence:
    result.add bencode(item)
  result.add("e")

proc bencode*(self: BENode): string =
  ## Encode BENode tree
  case self.kind:
  of tkInt:
    return self.intVal.bencode
  of tkBytes:
    return self.strVal.bencode
  of tkList:
    return self.listVal.bencode
  of tkDict:
    return self.dictVal.bencode
  of tkEof:
    raise newException(Exception, "unexpected tkEof item")

proc bencode*[A, B](pairs: openArray[(A, B)]): string =
  pairs.toTable.bencode

proc BEString*(s: string): BENode =
  BENode(kind: tkBytes, strVal:s)

proc BEDict*(t: Table[string, BENode]): BENode =
  BENode(kind: tkDict, dictVal: t)


proc toBENode*(j: JsonNode): BENode =
  ## Convert Json object to BENode
  case j.kind:
  of JString:
    return BEString(j.str)

  of JInt:
    return BENode(kind: tkInt, intVal: j.num.int)

  of JObject:
    result = BENode(kind: tkDict, dictVal: initTable[string, BENode]())
    for pair in j.pairs:
      let val = pair.val.toBENode()
      result.dictVal[pair.key] = val

  of JArray:
    result = BENode(kind: tkList, listVal: @[])
    for e in j.elems:
      result.listVal.add e.toBENode()

  else:
    raise newException(Exception, "unable to bencode unsupported type")


proc bencode*(j: JsonNode): string =
  j.toBENode.bencode
