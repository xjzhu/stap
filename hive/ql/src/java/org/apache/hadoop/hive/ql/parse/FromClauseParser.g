/**
   Licensed to the Apache Software Foundation (ASF) under one or more 
   contributor license agreements.  See the NOTICE file distributed with 
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the "License"); you may not use this file except in compliance with 
   the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
parser grammar FromClauseParser;

options
{
output=AST;
ASTLabelType=CommonTree;
backtrack=false;
k=3;
}

@members {
  @Override
  public Object recoverFromMismatchedSet(IntStream input,
      RecognitionException re, BitSet follow) throws RecognitionException {
    throw re;
  }
  @Override
  public void displayRecognitionError(String[] tokenNames,
      RecognitionException e) {
    gParent.errors.add(new ParseError(gParent, e, tokenNames));
  }
}

@rulecatch {
catch (RecognitionException e) {
  throw e;
}
}

//-----------------------------------------------------------------------------------

tableAllColumns
    : STAR
        -> ^(TOK_ALLCOLREF)
    | tableName DOT STAR
        -> ^(TOK_ALLCOLREF tableName)
    ;

// (table|column)
tableOrColumn
@init { gParent.msgs.push("table or column identifier"); }
@after { gParent.msgs.pop(); }
    :
    identifier -> ^(TOK_TABLE_OR_COL identifier)
    ;

expressionList
@init { gParent.msgs.push("expression list"); }
@after { gParent.msgs.pop(); }
    :
    expression (COMMA expression)* -> ^(TOK_EXPLIST expression+)
    ;

aliasList
@init { gParent.msgs.push("alias list"); }
@after { gParent.msgs.pop(); }
    :
    identifier (COMMA identifier)* -> ^(TOK_ALIASLIST identifier+)
    ;

//----------------------- Rules for parsing fromClause ------------------------------
// from [col1, col2, col3] table1, [col4, col5] table2
fromClause
@init { gParent.msgs.push("from clause"); }
@after { gParent.msgs.pop(); }
    : KW_FROM coalesceSource -> ^(TOK_FROM coalesceSource)
    | KW_FROM discretizeSource -> ^(TOK_FROM discretizeSource)
    | KW_FROM projectSource -> ^(TOK_FROM projectSource)
    | KW_FROM joinSource -> ^(TOK_FROM joinSource)
    ;
    
coalesceSource
@init {gParent.msgs.push("coalesce source"); }
@after {gParent.msgs.pop(); }
	:
	KW_COALESCE fromSource (KW_WITH valueDerivation KW_USING valueMode)? -> ^(TOK_COALESCE fromSource ^(TOK_DERIVE_VALUE valueDerivation valueMode)? )
	;

discretizeSource
@init {gParent.msgs.push("discretize source"); }
@after {gParent.msgs.pop(); }
	:
	KW_DISCRETIZE fromSource (KW_WITH valueDerivation KW_USING valueMode)? -> ^(TOK_DISCRETIZE fromSource ^(TOK_DERIVE_VALUE valueDerivation valueMode)? )
	;

projectSource
@init {gParent.msgs.push("project source"); }
@after {gParent.msgs.pop(); }
    : KW_PROJECT fromSource KW_ON projectee (KW_WITH valueOrMetadataDerivation)? -> ^(TOK_PROJECT fromSource projectee valueOrMetadataDerivation?)
    ;

projectee
@init {gParent.msgs.push("projectee"); }
@after {gParent.msgs.pop(); }
    : fromSource
    | KW_VIRTUALTRACK! intervalLength
    ;

joinSource
@init { gParent.msgs.push("join source"); }
@after { gParent.msgs.pop(); }
    : fromSource (( joinToken^ fromSource (KW_ON! expression)? )* | ( overlapJoinToken^ fromSource (KW_WITH! valueOrMetadataDerivation)? ) | (COMMA^ fromSource)+ )
    | uniqueJoinToken^ uniqueJoinSource (COMMA! uniqueJoinSource)+
    ;

uniqueJoinSource
@init { gParent.msgs.push("join source"); }
@after { gParent.msgs.pop(); }
    : KW_PRESERVE? fromSource uniqueJoinExpr
    ;

uniqueJoinExpr
@init { gParent.msgs.push("unique join expression list"); }
@after { gParent.msgs.pop(); }
    : LPAREN e1+=expression (COMMA e1+=expression)* RPAREN
      -> ^(TOK_EXPLIST $e1*)
    ;

uniqueJoinToken
@init { gParent.msgs.push("unique join"); }
@after { gParent.msgs.pop(); }
    : KW_UNIQUEJOIN -> TOK_UNIQUEJOIN;

joinToken
@init { gParent.msgs.push("join type specifier"); }
@after { gParent.msgs.pop(); }
    :
      KW_JOIN                      -> TOK_JOIN
    | KW_INNER KW_JOIN             -> TOK_JOIN
    | KW_CROSS KW_JOIN             -> TOK_CROSSJOIN
    | KW_LEFT  (KW_OUTER)? KW_JOIN -> TOK_LEFTOUTERJOIN
    | KW_RIGHT (KW_OUTER)? KW_JOIN -> TOK_RIGHTOUTERJOIN
    | KW_FULL  (KW_OUTER)? KW_JOIN -> TOK_FULLOUTERJOIN
    | KW_LEFT KW_SEMI KW_JOIN      -> TOK_LEFTSEMIJOIN
    ;

overlapJoinToken
    :
    KW_EXCLUSIVEJOIN -> TOK_EXCLUSIVEJOIN
    | KW_INTERSECTJOIN-> TOK_INTERSECTJOIN
    ;

lateralView
@init {gParent.msgs.push("lateral view"); }
@after {gParent.msgs.pop(); }
	:
	KW_LATERAL KW_VIEW KW_OUTER function tableAlias KW_AS identifier (COMMA identifier)*
	-> ^(TOK_LATERAL_VIEW_OUTER ^(TOK_SELECT ^(TOK_SELEXPR function identifier+ tableAlias)))
	|
	KW_LATERAL KW_VIEW function tableAlias KW_AS identifier (COMMA identifier)*
	-> ^(TOK_LATERAL_VIEW ^(TOK_SELECT ^(TOK_SELEXPR function identifier+ tableAlias)))
	;

tableAlias
@init {gParent.msgs.push("table alias"); }
@after {gParent.msgs.pop(); }
    :
    identifier -> ^(TOK_TABALIAS identifier)
    ;

fromSource
@init { gParent.msgs.push("from source"); }
@after { gParent.msgs.pop(); }
    :
    ((Identifier LPAREN)=> partitionedTableFunction | tableSource | subQuerySource) (lateralView^)*
    ;

tableBucketSample
@init { gParent.msgs.push("table bucket sample specification"); }
@after { gParent.msgs.pop(); }
    :
    KW_TABLESAMPLE LPAREN KW_BUCKET (numerator=Number) KW_OUT KW_OF (denominator=Number) (KW_ON expr+=expression (COMMA expr+=expression)*)? RPAREN -> ^(TOK_TABLEBUCKETSAMPLE $numerator $denominator $expr*)
    ;

splitSample
@init { gParent.msgs.push("table split sample specification"); }
@after { gParent.msgs.pop(); }
    :
    KW_TABLESAMPLE LPAREN  (numerator=Number) (percent=KW_PERCENT|KW_ROWS) RPAREN
    -> {percent != null}? ^(TOK_TABLESPLITSAMPLE TOK_PERCENT $numerator)
    -> ^(TOK_TABLESPLITSAMPLE TOK_ROWCOUNT $numerator)
    |
    KW_TABLESAMPLE LPAREN  (numerator=ByteLengthLiteral) RPAREN
    -> ^(TOK_TABLESPLITSAMPLE TOK_LENGTH $numerator)
    ;

tableSample
@init { gParent.msgs.push("table sample specification"); }
@after { gParent.msgs.pop(); }
    :
    tableBucketSample |
    splitSample
    ;

tableSource
@init { gParent.msgs.push("table source"); }
@after { gParent.msgs.pop(); }
    : tabname=tableName (props=tableProperties)? (ts=tableSample)? (KW_AS? alias=Identifier)?
    -> ^(TOK_TABREF $tabname $props? $ts? $alias?)
    ;
	
valueOrMetadataDerivation
@init { gParent.msgs.push("value or metadata derivation"); }
@after { gParent.msgs.pop(); }
    : KW_METADATA -> TOK_METADATA
    | valueDerivation KW_USING valueMode -> ^(TOK_DERIVE_VALUE valueDerivation valueMode)
    | valueDerivation COMMA KW_METADATA KW_USING valueMode -> ^(TOK_DERIVE_VALUE_AND_METADATA valueDerivation valueMode)
    | KW_METADATA COMMA valueDerivation KW_USING valueMode -> ^(TOK_DERIVE_VALUE_AND_METADATA valueDerivation valueMode)
    ;
    
valueDerivation
@init { gParent.msgs.push("value derivation"); }
@after { gParent.msgs.pop(); }
    : KW_VD_SUM -> TOK_VD_SUM
    | KW_VD_AVG -> TOK_VD_AVG
    | KW_VD_DIFF -> TOK_VD_DIFF
    | KW_VD_PRODUCT -> TOK_VD_PRODUCT
    | KW_VD_QUOTIENT -> TOK_VD_QUOTIENT
    | KW_VD_MAX -> TOK_VD_MAX
    | KW_VD_MIN -> TOK_VD_MIN
    | KW_VD_LEFT -> TOK_VD_LEFT
    | KW_VD_RIGHT -> TOK_VD_RIGHT
    ;

valueMode
@init { gParent.msgs.push("value mode"); }
@after { gParent.msgs.pop(); }
    : KW_EACH -> TOK_VM_EACH
    | KW_TOTAL -> TOK_VM_TOTAL
    ;
    
intervalLength
@init {gParent.msgs.push("intervalLength"); }
@after {gParent.msgs.pop(); }
    :
    Number -> ^(TOK_INTERVALLENGTH Number)
    ;

tableName
@init { gParent.msgs.push("table name"); }
@after { gParent.msgs.pop(); }
    :
    db=identifier DOT tab=identifier
    -> ^(TOK_TABNAME $db $tab)
    |
    tab=identifier
    -> ^(TOK_TABNAME $tab)
    ;

viewName
@init { gParent.msgs.push("view name"); }
@after { gParent.msgs.pop(); }
    :
    (db=identifier DOT)? view=identifier
    -> ^(TOK_TABNAME $db? $view)
    ;

subQuerySource
@init { gParent.msgs.push("subquery source"); }
@after { gParent.msgs.pop(); }
    :
    LPAREN queryStatementExpression RPAREN identifier -> ^(TOK_SUBQUERY queryStatementExpression identifier)
    | LPAREN coalesceSource RPAREN identifier? -> ^(TOK_GENTRACK coalesceSource identifier?)
    | LPAREN discretizeSource RPAREN identifier? -> ^(TOK_GENTRACK discretizeSource identifier?)
    | LPAREN projectSource RPAREN identifier? -> ^(TOK_GENTRACK projectSource identifier?)
    | LPAREN overlapJoinSource RPAREN identifier? -> ^(TOK_GENTRACK overlapJoinSource identifier?)
    ;

overlapJoinSource
    :
    fromSource ( overlapJoinToken^ fromSource (KW_WITH! valueOrMetadataDerivation)? )
    ;

//---------------------- Rules for parsing PTF clauses -----------------------------
partitioningSpec
@init { gParent.msgs.push("partitioningSpec clause"); }
@after { gParent.msgs.pop(); } 
   :
   partitionByClause orderByClause? -> ^(TOK_PARTITIONINGSPEC partitionByClause orderByClause?) |
   orderByClause -> ^(TOK_PARTITIONINGSPEC orderByClause) |
   distributeByClause sortByClause? -> ^(TOK_PARTITIONINGSPEC distributeByClause sortByClause?) |
   sortByClause -> ^(TOK_PARTITIONINGSPEC sortByClause) |
   clusterByClause -> ^(TOK_PARTITIONINGSPEC clusterByClause)
   ;

partitionTableFunctionSource
@init { gParent.msgs.push("partitionTableFunctionSource clause"); }
@after { gParent.msgs.pop(); } 
   :
   subQuerySource |
   tableSource |
   partitionedTableFunction
   ;

partitionedTableFunction
@init { gParent.msgs.push("ptf clause"); }
@after { gParent.msgs.pop(); } 
   :
   name=Identifier
   LPAREN KW_ON ptfsrc=partitionTableFunctionSource partitioningSpec?
     ((Identifier LPAREN expression RPAREN ) => Identifier LPAREN expression RPAREN ( COMMA Identifier LPAREN expression RPAREN)*)? 
   RPAREN alias=Identifier?
   ->   ^(TOK_PTBLFUNCTION $name $alias? partitionTableFunctionSource partitioningSpec? expression*)
   ; 

//----------------------- Rules for parsing whereClause -----------------------------
// where a=b and ...
whereClause
@init { gParent.msgs.push("where clause"); }
@after { gParent.msgs.pop(); }
    :
    KW_WHERE searchCondition -> ^(TOK_WHERE searchCondition)
    ;

searchCondition
@init { gParent.msgs.push("search condition"); }
@after { gParent.msgs.pop(); }
    :
    expression
    ;

//-----------------------------------------------------------------------------------
