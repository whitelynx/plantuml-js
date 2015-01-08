
{
  var TYPES_TO_PROPERTY_NAMES = {
    CallExpression:   "callee",
    MemberExpression: "object",
  };

  function filledArray(count, value) {
    var result = new Array(count), i;

    for (i = 0; i < count; i++) {
      result[i] = value;
    }

    return result;
  }

  function extractOptional(optional, index) {
    return optional ? optional[index] : undefined;
  }

  function extractList(list, index) {
    var result = new Array(list.length), i;

    for (i = 0; i < list.length; i++) {
      result[i] = list[i][index];
    }

    return result;
  }

  function buildList(first, rest, index) {
    return [first].concat(extractList(rest, index));
  }

  function buildTree(first, rest, builder) {
    var result = first, i;

    for (i = 0; i < rest.length; i++) {
      result = builder(result, rest[i]);
    }

    return result;
  }

  function buildBinaryExpression(first, rest) {
    return buildTree(first, rest, function(result, element) {
      return {
        type:     "BinaryExpression",
        operator: element[1],
        left:     result,
        right:    element[3]
      };
    });
  }

  function buildLogicalExpression(first, rest) {
    return buildTree(first, rest, function(result, element) {
      return {
        type:     "LogicalExpression",
        operator: element[1],
        left:     result,
        right:    element[3]
      };
    });
  }

  function optionalList(value) {
    return value !== null ? value : [];
  }
}

start
 = instructions
 
instructions
  = first:instruction? rest:(EOS instruction)* EOS?  {
    return ( first ? [first] : []). concat(extractList(rest,1));
  }
  
instruction
  = UMLStatment
  / AnnotaionElement
  / FormattingElement
  / ConstantDefinition
  / Comment

/* -----         Statements         ----- */

UMLStatment
  = ElementRelationship
  / ClassDeclaration
  / EnumDeclaration
  
ElementRelationship
  = lhs:Identifier 
    lhs_card:( __ StringLiteral)?
     _ rel:RelationExpression _
    rhs_card:(StringLiteral __ )?
    rhs:Identifier 
    lbl:( _ LabelExpression) ? {
    return {
        left: {ref: lhs, cardinality: extractOptional(lhs_card,1) },
        right: {ref: rhs, cardinality: extractOptional(rhs_card,0) },
        relationship: rel,
        label: extractOptional(lbl,1)
    };
  }

ClassDeclaration
  = ClassToken __ id:Identifier 
    stereotype:( _ StereotypeExpression )? 
    body:( _ "{" LineBreak* ClassBody  LineBreak* "}" )?  {
    return {
      umlobjtype: "class",
      id: id,
      body:  extractOptional(body,3),
      stereotype: extractOptional(stereotype, 1)
    };
  }
  
EnumDeclaration
  = EnumToken __ id:Identifier 
    body:( _ "{" LineBreak* EnumBody LineBreak* "}" )?  {
    return {
      umlobjtype: "enum",
      id: id,
      body:  optionalList(extractOptional(body, 3)),
    };
  }
  
/*** Formatting Elements ***/
FormattingElement
  = DocFormatHide
  / SetRenderElement
  
 DocFormatHide 
  = HideToken __ selector:$( (UMLObject (_ StereotypeExpression)?) / Annotation / EmptyLiteral ) 
    _ element:$( "stereotype"/"method")? {
    return {
      type: "hide",
      selector: selector,
      element: element
    }
  }

SetRenderElement
  = SetToken __ cmd:$(NSSepToken) __ val:StringLiteral {
    return {
      type:"render command",
      command: cmd,
      value: val
    };
  }

/*** Annotation Elements ***/
AnnotaionElement 
  = HeaderBlock
  / FooterBlock
  / TitleBlock
  / NoteBlock
  / LegendBlock
 
HeaderBlock
  = HeaderToken 
    LineBreak body:$( !(LineBreak EndHeaderToken) .)* LineBreak
    EndHeaderToken {
    return {
      type: "header block",
      body: body.trim()
    };
  }
  
FooterBlock
  = FooterToken
    LineBreak body:$( !(LineBreak EndToken __ FooterToken) .)* LineBreak
	EndToken __ FooterToken {
    return {
	    type: "footer",
		body: body.trim()
	}
  }

TitleBlock
  = TitleToken __ title:$(SourceCharacter*) {
    return {
      type: "title",
      text: title.trim()
    };
  }

NoteBlock
  = NoteToken __ alias:( "as" __ Identifier)?
    LineBreak txt:$( !(LineBreak EndToken __ NoteToken) .)* LineBreak
    EndToken __ NoteToken
  {
		return {
		  type:"note",
		  text: txt,
		  alias: extractOptional(alias,2)
		};
  }
	/
	NoteToken __ alias:( "as" __ Identifier __)? txt:$(SourceCharacter)* 
  {
		return {
		  type:"note",
		  text: txt,
		  alias: extractOptional(alias,2)
		};
  }

LegendBlock
  = LegendToken meh:(__ Direction)?
    LineBreak txt:$( !(LineBreak EndToken __ LegendToken) .)* LineBreak
    EndToken __ LegendToken {
    return {
	  type: "legend",
	  text: txt,
	  direction: extractOptional(meh,1)
    };
  }

/*** Other ***/
ConstantDefinition
 = "!define" __ key:Identifier __ sub:$(SourceCharacter+) {
    return {
      type: "define",
      search: key,
      replacement: sub
    };
  }

Comment
  = SQUOTE comment:$(SourceCharacter*) {
      return {type:"comment", text:comment};
    }


/* -----       Expressions          ----- */
Identifier
  = $(!ReservedWord IdentifierStart (IdentifierPart)*)
  
LabelText
  = $( !":" _ (StringLiteral / (!LabelTerminator SourceCharacter)+) )

LabelExpression
  =  ":" _ text:LabelText _ arrow:LabelTerminator {
    return { 
      text: text, 
      direction: arrow
    }
  }
  
 /** Relation Expression**/ 
RelationExpression 
  = left:RelationshipLeftEnd? body:RelationshipBody right:RelationshipRightEnd? {
    return {
      left: left,
      right: right,
      body: body
    };
  }
 
RelationshipBody
  = lhs:$(SolidLineToken+) hint:Direction?  rhs:$(SolidLineToken*) { 
    return { 
      type: "solid", 
      len: lhs.length + rhs.length, 
      hint: hint||undefined
    } 
  }
  / lhs:$(BrokenLineToken+) hint:Direction?  rhs:$(BrokenLineToken*) { 
    return { 
      type: "solid", 
      len: lhs.length + rhs.length, 
      hint: hint||undefined
    } 
  }

/*** class expressions **/
ClassBody
  = rest:( (MethodExpression/PropertyExpression) EOS)* {
    return extractList(rest, 0)
  }
  
MethodExpression
  = _ scope:( ScopeModifier __ )? 
    dtype:DatatypeExpression __ id:Identifier _ "()" {
    return {
       type: "method",
       name: id,
       data_type: dtype,
       scope: extractOptional(scope,0)
     }
   }
  
PropertyExpression
   = _ scope:( ScopeModifier _)?
     id:Identifier ":" _ dtype:DatatypeExpression
     attrib:( _ AttributeExpression)?
     stereo:( _ StereotypeExpression)? _ {
     return {
       type: "property",
       name: id,
       data_type: dtype,
       attributes: extractOptional(attrib,1),
       scope: extractOptional(scope,0),
       stereotype: extractOptional(stereo,1)
     }
   }
   
AttributeExpression
  = "{" list:AttributeBody "}" { return list; }

AttributeBody 
  = first:AttributeMembers rest:("," AttributeMembers)*  {
    return buildList(first,rest,1)
  }
  
AttributeMembers
  = item:$(_ Identifier)* _ {return item.trim() }
    

/*** Enum Expressions ***/
EnumMembers
  = _ id:Identifier {
    return {
      type:"enum member",
      name: id
    };
  }

EnumBody 
  = rest:(EnumMembers EOS )* {
    return extractList(rest, 0)
  }  

DatatypeExpression
  = ArrayExpression
  / Identifier
  
ArrayExpression
  = dtype:Identifier "[" size:$(DIGIT*)? "]"{
    return {
      type: "array",
      basetype: dtype,
      size: size
    }
  }

/*** Stereotype Expressions ***/
StereotypeExpression 
  = StereotypeOpenToken
    _ first: StereotypeTerm rest:("," StereotypeTerm)* _
    StereotypeCloseToken 
  {
    return buildList(first,rest,1);
  }

StereotypeTerm
  = _ spot:(StereotypeSpotExpression _ )? id:$(_ Identifier)* _ {
    return {
	  name: id,
	  spot: extractOptional(spot,1)
	};
  }

StereotypeSpotExpression
  = "(" id:IdentifierPart "," color:(HexIntegerLiteral/id:Identifier) ")" {
    return {
      shorthand:id,
      color: color
    };
  }
  
/* -----         Literals           ----- */
StringLiteral "string"
  = DQUOTE chars:$(DoubleStringCharacter)* DQUOTE {
      return { type: "Literal", value: chars };
    }
 
DoubleStringCharacter
  = !(DQUOTE / Escape) SourceCharacter
  / LineContinuation

HexIntegerLiteral
  = "#" digits:$HEXDIG+ {
      return { type: "Literal", value: parseInt(digits, 16) };
  }
  
EmptyLiteral
  = EmptyToken { return { type: "Literal", value: "empty" }; }

ScopeModifier
  = PrivateToken   {return {type:"scope modifier", value:"private"        }; }
  / ProtectedToken {return {type:"scope modifier", value:"protected"      }; }
  / PackageToken   {return {type:"scope modifier", value:"package private"}; }
  / PublicToken    {return {type:"scope modifier", value:"public"         }; }
  
RelationshipLeftEnd
  = LeftExtendsToken {return {type:"relation end", value: "left extend"}; }
  / LeftArrowToken   {return {type:"relation end", value: "left arrow" }; }
  / CompositionToken {return {type:"relation end", value: "composition"}; }
  / AggregationToken {return {type:"relation end", value: "aggregation"}; }
  / InterfaceToken   {return {type:"relation end", value: "interface"  }; }

RelationshipRightEnd
  = RightExtendsToken {return {type:"relation end", value: "right extend"}; }
  / RightArrowToken   {return {type:"relation end", value: "right arrow" }; }
  / CompositionToken  {return {type:"relation end", value: "composition" }; }
  / AggregationToken  {return {type:"relation end", value: "aggregation" }; }
  / InterfaceToken    {return {type:"relation end", value: "interface"   }; }

  
/* -----      const strings         ----- */

/*-- Words --*/
ReservedWord 
  = RenderCommands
  / UMLObject
  / Annotation
  / EmptyLiteral

RenderCommands 
  = HideToken
  / SetToken
  / NSSepToken
  
UMLObject
  = ClassToken
  / EnumToken
  
Annotation
  = TitleToken
  / HeaderToken
  / FooterToken
  / LegendToken
  / NoteToken
  
Direction
  = "up"i
  / "down"i
  / "left"i
  / "right"i
  
/* litterals */
EmptyToken  = "empty"i    !IdentifierPart

/* UML Objects */
ClassToken   = "class"i   !IdentifierPart
EnumToken    = "enum"i    !IdentifierPart
PackageToken = "package"i !IdentifierPart

/* Annotations */
TitleToken  = "title"i   !IdentifierPart
HeaderToken = "header"i   !IdentifierPart
FooterToken = "footer"i   !IdentifierPart
LegendToken = "legend"i   !IdentifierPart
NoteToken   = "note"i     !IdentifierPart

/* Render Commands */
HideToken   = "hide"i  !IdentifierPart
SetToken    = "set"i   !IdentifierPart
NSSepToken  = "namespaceSeparator"i !IdentifierPart

/* Reserved Words */
EndToken    = "end"i   !IdentifierPart
EndHeaderToken = EndToken __ HeaderToken

/* Symbols */
PrivateToken   = "-" 
ProtectedToken = "#" 
PackageToken   = "~" 
PublicToken    = "+"

StereotypeOpenToken  = "<<"
StereotypeCloseToken = ">>"

LeftExtendsToken  = "<|"
RightExtendsToken = "|>"
RightArrowToken   = ">"  
LeftArrowToken    = "<"
CompositionToken  = "o"  
AggregationToken  = "*"
InterfaceToken    =  "()"

SolidLineToken  = "-" 
BrokenLineToken = "." 


/* -----  common char seq and sets  ----- */
LabelTerminator
 = "<" 
 / ">"
 / EOS

LineContinuation
  = Escape $( LF / CR / CRLF )
 
SourceCharacter
  = !(LF/CR) .
  
IdentifierStart
  = ALPHA
  / "_"
 
IdentifierPart
  = DIGIT 
  / ALPHA
  / "_"
  / "."

Escape
  = "\\"

SQUOTE
  = "'"
__
  = WSP+
_
  = WSP*
  
LineBreak
  = WSP* (CRLF  / LF  / CR ) WSP*
  
EOS
  = $(LineBreak / (WSP* ";" WSP*))+  // new-line or ; terminated statements
  / $(WSP* & "}" )                    // new of enum/class body
  / $(WSP* &SQUOTE)                   // begining of comment
 

 /*
 * Augmented BNF for Syntax Specifications: ABNF
 *
 * http://tools.ietf.org/html/rfc5234
 */

/* http://tools.ietf.org/html/rfc5234#appendix-B Core ABNF of ABNF */
ALPHA
  = [\x41-\x5A]
  / [\x61-\x7A]

BIT
  = "0"
  / "1"

CHAR
  = [\x01-\x7F]

CR
  = "\x0D"

CRLF
  = CR LF

CTL
  = [\x00-\x1F]
  / "\x7F"

DIGIT
  = [\x30-\x39]

DQUOTE
  = [\x22]

HEXDIG
  = DIGIT
  / "A"i
  / "B"i
  / "C"i
  / "D"i
  / "E"i
  / "F"i

HTAB
  = "\x09"

LF
  = "\x0A"

LWSP
  = $(WSP / CRLF WSP)*

OCTET
  = [\x00-\xFF]

SP
  = "\x20"

VCHAR
  = [\x21-\x7E]

WSP
  = SP
  / HTAB
  
  