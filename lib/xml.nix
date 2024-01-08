with builtins;

rec {
  escapeXML = string:
    replaceStrings
      [ "&" "<" ">" "\"" "'" ]
      [ "&amp;" "&lt;" "&gt;" "&quot;" "&apos;" ]
      (toString string);

  generateXMLInner = { obj, indent ? 0 }:
    let
      indentStr = concatStringsSep "" (genList (_: " ") indent);
    in
    if isList obj then
      concatStringsSep ""
        (
          map (x: generateXMLInner { obj = x; indent = indent; }) obj
        )
    else if isAttrs obj then
      concatStringsSep ""
        (
          map
            (key:
              let
                objValue = obj.${key};
                value = objValue._value or objValue;
                opener = "\n${indentStr}<${key}";
                attributes =
                  if objValue ? _attrs then
                    concatStringsSep ""
                      (
                        map
                          (attrName:
                            let
                              attrValue = objValue._attrs.${attrName};
                            in
                            if attrValue == null then ""
                            else " ${attrName}=\"${escapeXML attrValue}\""
                          )
                          (attrNames objValue._attrs)
                      )
                  else "";
                contentAndCloser =
                  if isAttrs value && length (attrNames value) == 0 ||
                    isList value && length value == 0 then
                    " />"
                  else if isString value || isInt value then
                    ">${escapeXML value}</${key}>"
                  else
                    ">${generateXMLInner { obj = value; indent = indent + 2; }}\n${indentStr}</${key}>";
              in
              if key == "_attrs" || key == "_value" then ""
              else "${opener}${attributes}${contentAndCloser}"
            )
            (attrNames obj)
        )
    else escapeXML obj;
  generateXML = obj:
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>${generateXMLInner { obj = obj; }}";
}
