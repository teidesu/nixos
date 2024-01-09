{ lib, ... }@inputs:

rec {
  mkValue = value:
    if builtins.isInt value then builtins.toString value
    else if builtins.isString value then "'" + (builtins.replaceStrings [ "'" ] [ "''" ] value) + "'"
    else if builtins.isAttrs value then
      if builtins.hasAttr "_raw" value then "(" + value._raw + ")"
      else mkValue (builtins.toJSON value)
    else if value == null then "null"
    else throw "invalid type: ${builtins.typeOf value} (value ${builtins.toString value})";
  mkIdent = value: "\"" + (builtins.replaceStrings [ "\"" ] [ "\"\"" ] value) + "\"";

  mkTableName = table: if builtins.isList table then builtins.concatStringsSep "." table else table;

  sql = sql: { _raw = sql; };

  insert = { into, value, orReplace ? false }:
    let
      columns = builtins.attrNames value;
      values = builtins.map (name: value.${name}) columns;
      cmd = if orReplace then "insert or replace" else "insert";
    in
    "${cmd} into ${mkTableName into} " +
    "(${builtins.concatStringsSep ", " (builtins.map mkIdent columns)}) " +
    "values (${builtins.concatStringsSep ", " (builtins.map mkValue values)})";

  mkWhere = where:
    if builtins.isAttrs where then
      builtins.concatStringsSep " and " (builtins.map (name: "${name} = ${mkValue where.${name}}") (builtins.attrNames where))
    else where;

  select =
    { from
    , where
    , orderBy ? null
    , limit ? null
    , offset ? null
    , columns ? null
    }:
    let
      whereClause = if where != null then " where ${mkWhere where}" else "";
      orderByClause = if orderBy != null then " order by ${orderBy}" else "";
      limitClause = if limit != null then " limit ${limit}" else "";
      offsetClause = if offset != null then " offset ${offset}" else "";
      columnsClause = if columns != null then builtins.concatStringsSep ", " (builtins.map mkIdent columns) else "*";
    in
    "select ${columnsClause} from ${mkTableName from}${whereClause}${orderByClause}${limitClause}${offsetClause}";

  script = statements:
    builtins.concatStringsSep "\n" (
      builtins.map (statement: statement + ";") (lib.lists.flatten statements)
    );
}
