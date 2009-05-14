/* 
 * [The "BSD licence"]
 * Copyright (c) 2009 Ben Gruver
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

parser grammar smaliParser;

options {
	tokenVocab=smaliLexer;
	output=AST;
	ASTLabelType=CommonTree;
}

tokens {
	//I_* tokens are imaginary tokens used as parent AST nodes
	I_CLASS_DEF;
	I_SUPER;
	I_ACCESS_LIST;
	I_METHODS;
	I_FIELDS;
	I_FIELD;
	I_FIELD_TYPE;
	I_FIELD_INITIAL_VALUE;
	I_METHOD;
	I_METHOD_PROTOTYPE;
	I_METHOD_RETURN_TYPE;
	I_REGISTERS;
	I_LABELS;
	I_LABEL;
	I_ARRAY_ELEMENT_SIZE;
	I_ARRAY_ELEMENTS;	
	I_PACKED_SWITCH_START_KEY;
	I_PACKED_SWITCH_BASE_OFFSET;
	I_PACKED_SWITCH_TARGET_COUNT;
	I_PACKED_SWITCH_TARGETS;
	I_SPARSE_SWITCH_BASE_OFFSET;
	I_SPARSE_SWITCH_KEYS;
	I_SPARSE_SWITCH_TARGET_COUNT;
	I_SPARSE_SWITCH_TARGETS;
	I_CATCH;
	I_CATCHES;
	I_CATCH_ADDRESS;
	I_STATEMENTS;
	I_STATEMENT_FORMAT10t;
	I_STATEMENT_FORMAT10x;
	I_STATEMENT_FORMAT11n;
	I_STATEMENT_FORMAT11x;
	I_STATEMENT_FORMAT12x;
	I_STATEMENT_FORMAT20t;
	I_STATEMENT_FORMAT21c_TYPE;
	I_STATEMENT_FORMAT21c_FIELD;
	I_STATEMENT_FORMAT21c_STRING;
	I_STATEMENT_FORMAT21h;
	I_STATEMENT_FORMAT21s;
	I_STATEMENT_FORMAT21t;
	I_STATEMENT_FORMAT22b;
	I_STATEMENT_FORMAT22c_FIELD;
	I_STATEMENT_FORMAT22c_TYPE;
	I_STATEMENT_FORMAT22s;
	I_STATEMENT_FORMAT22t;
	I_STATEMENT_FORMAT22x;
	I_STATEMENT_FORMAT23x;
	I_STATEMENT_FORMAT30t;
	I_STATEMENT_FORMAT31c;
	I_STATEMENT_FORMAT31i;
	I_STATEMENT_FORMAT31t;	
	I_STATEMENT_FORMAT32x;
	I_STATEMENT_FORMAT35c_METHOD;
	I_STATEMENT_FORMAT3rc_METHOD;
	I_STATEMENT_FORMAT51l;
	I_STATEMENT_ARRAY_DATA;
	I_STATEMENT_PACKED_SWITCH;
	I_STATEMENT_SPARSE_SWITCH;
	I_REGISTER_RANGE;
	I_REGISTER_LIST;
	
	CLASS_NAME;
	MEMBER_NAME;
}

@header {
package org.JesusFreke.smali;

import org.JesusFreke.dexlib.code.Format.*;
}


smali_file:	header methods_and_fields -> ^(I_CLASS_DEF header methods_and_fields);

header	:	class_spec super_spec;

class_spec
	:	CLASS_DIRECTIVE access_list CLASS_DESCRIPTOR -> CLASS_DESCRIPTOR access_list;

super_spec
	:	SUPER_DIRECTIVE CLASS_DESCRIPTOR -> ^(I_SUPER[$start, "I_SUPER"] CLASS_DESCRIPTOR);

access_list
	:	ACCESS_SPEC+ -> ^(I_ACCESS_LIST[$start,"I_ACCESS_LIST"] ACCESS_SPEC+);

methods_and_fields
	:	(method | field)* -> ^(I_METHODS method*) ^(I_FIELDS field*);

field	:	FIELD_DIRECTIVE access_list MEMBER_NAME field_type_descriptor literal?
		-> ^(I_FIELD[$start, "I_FIELD"] MEMBER_NAME access_list ^(I_FIELD_TYPE field_type_descriptor) ^(I_FIELD_INITIAL_VALUE literal)?);
		
method	:	METHOD_DIRECTIVE access_list  MEMBER_NAME method_prototype 
		registers_directive
		statements 
		END_METHOD_DIRECTIVE
		-> ^(I_METHOD[$start, "I_METHOD"] MEMBER_NAME method_prototype access_list registers_directive statements);

method_prototype
	:	OPEN_PAREN field_type_descriptor* CLOSE_PAREN type_descriptor
		-> ^(I_METHOD_PROTOTYPE[$start, "I_METHOD_PROTOTYPE"] ^(I_METHOD_RETURN_TYPE type_descriptor) field_type_descriptor*);



registers_directive
	:	REGISTERS_DIRECTIVE integral_literal
	-> ^(I_REGISTERS[$start, "I_REGISTERS"] integral_literal);


fully_qualified_method
	:	CLASS_NAME MEMBER_NAME method_prototype;

fully_qualified_field
	:	CLASS_NAME MEMBER_NAME field_type_descriptor;

statements
	scope {int currentAddress;}
	:	{$statements::currentAddress = 0;}
		(	instruction {$statements::currentAddress += $instruction.size/2;}
		|	catch_directive
		|	label)*		
		-> ^(I_LABELS label*) ^(I_STATEMENTS instruction*) ^(I_CATCHES catch_directive*);

catch_directive
	:	CATCH_DIRECTIVE field_type_descriptor from=offset_or_label to=offset_or_label using=offset_or_label
		-> ^(I_CATCH[$start, "I_CATCH"] I_CATCH_ADDRESS[$start, Integer.toString($statements::currentAddress)] field_type_descriptor $from $to $using)
	;
label
	:	LABEL -> ^(I_LABEL LABEL {new CommonTree(new CommonToken(INTEGER_LITERAL,Integer.toString($statements::currentAddress)))});
	
instruction returns [int size]
	@init {boolean needsNop = false;}
	:	//e.g. goto endloop:
		//e.g. goto +3
		INSTRUCTION_FORMAT10t (LABEL | OFFSET) {$size = Format10t.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT10t[$start, "I_STATEMENT_FORMAT10t"] INSTRUCTION_FORMAT10t LABEL? OFFSET?)
	|	//e.g. return
		INSTRUCTION_FORMAT10x {$size = Format10x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT10x[$start, "I_STATEMENT_FORMAT10x"] INSTRUCTION_FORMAT10x)
	|	//e.g. const/4 v0, 5
		INSTRUCTION_FORMAT11n REGISTER integral_literal {$size = Format11n.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT11n[$start, "I_STARTMENT_FORMAT11n"] INSTRUCTION_FORMAT11n REGISTER integral_literal)
	|	//e.g. move-result-object v1
		INSTRUCTION_FORMAT11x REGISTER {$size = Format11x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT11x[$start, "I_STATEMENT_FORMAT11x"] INSTRUCTION_FORMAT11x REGISTER)
	|	//e.g. move v1 v2
		INSTRUCTION_FORMAT12x REGISTER REGISTER {$size = Format12x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT12x[$start, "I_STATEMENT_FORMAT12x"] INSTRUCTION_FORMAT12x REGISTER REGISTER)		
	|	//e.g. goto/16 endloop:
		INSTRUCTION_FORMAT20t (LABEL | OFFSET) {$size = Format20t.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT20t[$start, "I_STATEMENT_FORMAT20t"] INSTRUCTION_FORMAT20t LABEL? OFFSET?)
	|	//e.g. sget_object v0 java/lang/System/out LJava/io/PrintStream;
		INSTRUCTION_FORMAT21c_FIELD REGISTER fully_qualified_field {$size = Format21c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT21c_FIELD[$start, "I_STATEMENT_FORMAT21c_FIELD"] INSTRUCTION_FORMAT21c_FIELD REGISTER fully_qualified_field)
	|	//e.g. const-string v1 "Hello World!"
		INSTRUCTION_FORMAT21c_STRING REGISTER STRING_LITERAL {$size = Format21c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT21c_STRING[$start, "I_STATEMENT_FORMAT21c_STRING"] INSTRUCTION_FORMAT21c_STRING REGISTER STRING_LITERAL)
	|	//e.g. const-class v2 org/JesusFreke/HelloWorld2/HelloWorld2
		INSTRUCTION_FORMAT21c_TYPE REGISTER class_or_array_type_descriptor {$size = Format21c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT21c_TYPE[$start, "I_STATEMENT_FORMAT21c"] INSTRUCTION_FORMAT21c_TYPE REGISTER class_or_array_type_descriptor)
	|	//e.g. const/high16 v1, 1234
		INSTRUCTION_FORMAT21h REGISTER integral_literal {$size = Format21h.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT21h[$start, "I_STATEMENT_FORMAT21h"] INSTRUCTION_FORMAT21h REGISTER integral_literal)
	|	//e.g. const/16 v1, 1234
		INSTRUCTION_FORMAT21s REGISTER integral_literal {$size = Format21s.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT21s[$start, "I_STATEMENT_FORMAT21s"] INSTRUCTION_FORMAT21s REGISTER integral_literal)
	|	//e.g. if-eqz v0, endloop:
		INSTRUCTION_FORMAT21t REGISTER (LABEL | OFFSET) {$size = Format21t.Format.getByteCount();}	
		-> ^(I_STATEMENT_FORMAT21t[$start, "I_STATEMENT_FORMAT21t"] INSTRUCTION_FORMAT21t REGISTER LABEL? OFFSET?)
	|	//e.g. add-int v0, v1, 123
		INSTRUCTION_FORMAT22b REGISTER REGISTER integral_literal {$size = Format22b.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22b[$start, "I_STATEMENT_FORMAT22b"] INSTRUCTION_FORMAT22b REGISTER REGISTER integral_literal)
	|	//e.g. iput-object v1, v0 org/JesusFreke/HelloWorld2/HelloWorld2.helloWorld Ljava/lang/String;
		INSTRUCTION_FORMAT22c_FIELD REGISTER REGISTER fully_qualified_field {$size = Format22c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22c_FIELD[$start, "I_STATEMENT_FORMAT22c_FIELD"] INSTRUCTION_FORMAT22c_FIELD REGISTER REGISTER fully_qualified_field)
	|	//e.g. instance-of v0, v1, Ljava/lang/String;
		INSTRUCTION_FORMAT22c_TYPE REGISTER REGISTER field_type_descriptor {$size = Format22c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22c_TYPE[$start, "I_STATEMENT_FORMAT22c_TYPE"] INSTRUCTION_FORMAT22c_TYPE REGISTER REGISTER field_type_descriptor)
	|	//e.g. add-int/lit16 v0, v1, 12345
		INSTRUCTION_FORMAT22s REGISTER REGISTER integral_literal {$size = Format22s.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22s[$start, "I_STATEMENT_FORMAT22s"] INSTRUCTION_FORMAT22s REGISTER REGISTER integral_literal)
	|	//e.g. if-eq v0, v1, endloop:
		INSTRUCTION_FORMAT22t REGISTER REGISTER (LABEL | OFFSET) {$size = Format22t.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22t[$start, "I_STATEMENT_FFORMAT22t"] INSTRUCTION_FORMAT22t REGISTER REGISTER LABEL? OFFSET?)
	|	//e.g. move/from16 v1, v1234
		INSTRUCTION_FORMAT22x REGISTER REGISTER {$size = Format22x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT22x[$start, "I_STATEMENT_FORMAT22x"] INSTRUCTION_FORMAT22x REGISTER REGISTER)
	|	//e.g. add-int v1, v2, v3
		INSTRUCTION_FORMAT23x REGISTER REGISTER REGISTER {$size = Format23x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT23x[$start, "I_STATEMENT_FORMAT23x"] INSTRUCTION_FORMAT23x REGISTER REGISTER REGISTER)
	|	//e.g. goto/32 endloop:
		INSTRUCTION_FORMAT30t (LABEL | OFFSET) {$size = Format30t.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT30t[$start, "I_STATEMENT_FORMAT30t"] INSTRUCTION_FORMAT30t LABEL? OFFSET?)
	|	//e.g. const-string/jumbo v1 "Hello World!"
		INSTRUCTION_FORMAT31c REGISTER STRING_LITERAL {$size = Format31c.Format.getByteCount();}
		->^(I_STATEMENT_FORMAT31c[$start, "I_STATEMENT_FORMAT31c"] INSTRUCTION_FORMAT31c REGISTER STRING_LITERAL)	
	|	//e.g. const v0, 123456
		INSTRUCTION_FORMAT31i REGISTER fixed_32bit_literal {$size = Format31i.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT31i[$start, "I_STATEMENT_FORMAT31i"] INSTRUCTION_FORMAT31i REGISTER fixed_32bit_literal)
	|	//e.g. fill-array-data v0, ArrayData:
		INSTRUCTION_FORMAT31t REGISTER (LABEL | OFFSET) {$size = Format31t.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT31t[$start, "I_STATEMENT_FORMAT31t"] INSTRUCTION_FORMAT31t REGISTER LABEL? OFFSET?)
	|	//e.g. move/16 v4567, v1234
		INSTRUCTION_FORMAT32x REGISTER REGISTER {$size = Format32x.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT32x[$start, "I_STATEMENT_FORMAT32x"] INSTRUCTION_FORMAT32x REGISTER REGISTER)		
	|	//e.g. invoke-virtual {v0,v1} java/io/PrintStream/print(Ljava/lang/Stream;)V
		INSTRUCTION_FORMAT35c_METHOD OPEN_BRACKET register_list CLOSE_BRACKET fully_qualified_method {$size = Format35c.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT35c_METHOD[$start, "I_STATEMENT_FORMAT35c_METHOD"] INSTRUCTION_FORMAT35c_METHOD register_list fully_qualified_method)
	|	//e.g. invoke-virtual/range {v25..v26} java/lang/StringBuilder/append(Ljava/lang/String;)Ljava/lang/StringBuilder;
		INSTRUCTION_FORMAT3rc_METHOD OPEN_BRACKET register_range CLOSE_BRACKET fully_qualified_method {$size = Format3rc.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT3rc_METHOD[$start, "I_STATEMENT_FORMAT3rc_METHOD"] INSTRUCTION_FORMAT3rc_METHOD register_range fully_qualified_method)
	|	//e.g. const-wide v0, 5000000000L
		INSTRUCTION_FORMAT51l REGISTER (LONG_LITERAL | DOUBLE_LITERAL) {$size = Format51l.Format.getByteCount();}
		-> ^(I_STATEMENT_FORMAT51l[$start, "I_STATEMENT_FORMAT51l"] INSTRUCTION_FORMAT51l REGISTER LONG_LITERAL? DOUBLE_LITERAL?)		
	|	
		ARRAY_DATA_DIRECTIVE
		{	
			if (($statements::currentAddress \% 2) != 0) {
				needsNop = true;
				$size = 2;
			} else {
				$size = 0;
			}
		}
		
		integral_literal (fixed_literal {$size+=$fixed_literal.size;})* END_ARRAY_DATA_DIRECTIVE
		{$size = (($size + 1)/2)*2 + 8;}
		
		/*add a nop statement before this if needed to force the correct alignment*/
 		->	{needsNop}?	^(I_STATEMENT_FORMAT10x[$start,  "I_STATEMENT_FORMAT10x"] INSTRUCTION_FORMAT10x[$start, "nop"]) 
 					^(I_STATEMENT_ARRAY_DATA ^(I_ARRAY_ELEMENT_SIZE integral_literal) ^(I_ARRAY_ELEMENTS fixed_literal*))

 		->	^(I_STATEMENT_ARRAY_DATA ^(I_ARRAY_ELEMENT_SIZE integral_literal) ^(I_ARRAY_ELEMENTS fixed_literal*))
 	|	
 		PACKED_SWITCH_DIRECTIVE
 		{
 			int targetCount = 0;
 			if (($statements::currentAddress \% 2) != 0) {
 				needsNop = true;
 				$size = 2;
 			} else {
 				$size = 0;
 			}
 		}
 		
 		base_offset = offset_or_label
 		
 		fixed_32bit_literal 
 		
 		(switch_target += offset_or_label {$size+=4; targetCount++;})*
 		
 		END_PACKED_SWITCH_DIRECTIVE {$size = $size + 8;}
 		
		/*add a nop statement before this if needed to force the correct alignment*/
 		->	{needsNop}?	^(I_STATEMENT_FORMAT10x[$start,  "I_STATEMENT_FORMAT10x"] INSTRUCTION_FORMAT10x[$start, "nop"]) 
 					^(I_STATEMENT_PACKED_SWITCH[$start, "I_STATEMENT_PACKED_SWITCH"] 
 						^(I_PACKED_SWITCH_BASE_OFFSET[$start, "I_PACKED_SWITCH_BASE_OFFSET"] $base_offset) 
 						^(I_PACKED_SWITCH_START_KEY[$start, "I_PACKED_SWITCH_START_KEY"] fixed_32bit_literal) 
 						^(I_PACKED_SWITCH_TARGETS[$start, "I_PACKED_SWITCH_TARGETS"] I_PACKED_SWITCH_TARGET_COUNT[$start, Integer.toString(targetCount)] $switch_target*)
 					)
 					
		->	^(I_STATEMENT_PACKED_SWITCH[$start, "I_STATEMENT_PACKED_SWITCH"] 
				^(I_PACKED_SWITCH_BASE_OFFSET[$start, "I_PACKED_SWITCH_BASE_OFFSET"] $base_offset) 
				^(I_PACKED_SWITCH_START_KEY[$start, "I_PACKED_SWITCH_START_KEY"] fixed_32bit_literal) 
				^(I_PACKED_SWITCH_TARGETS[$start, "I_PACKED_SWITCH_TARGETS"] I_PACKED_SWITCH_TARGET_COUNT[$start, Integer.toString(targetCount)] $switch_target*)
			)
 		
 	|
 		SPARSE_SWITCH_DIRECTIVE
 		{
 			int targetCount = 0;
 			if (($statements::currentAddress \% 2) != 0) {
 				needsNop = true;
 				$size = 2;
 			} else {
 				$size = 0;
 			}
 		}
 		
 		base_offset = offset_or_label
 		
 		(fixed_32bit_literal switch_target += offset_or_label {$size += 8; targetCount++;})*
 		
 		END_SPARSE_SWITCH_DIRECTIVE {$size = $size + 4;}
 		
		/*add a nop statement before this if needed to force the correct alignment*/
 		->	{needsNop}?	^(I_STATEMENT_FORMAT10x[$start,  "I_STATEMENT_FORMAT10x"] INSTRUCTION_FORMAT10x[$start, "nop"]) 
 					^(I_STATEMENT_SPARSE_SWITCH[$start, "I_STATEMENT_SPARSE_SWITCH"]
 						^(I_SPARSE_SWITCH_BASE_OFFSET[$start, "I_SPARSE_SWITCH_BASE_OFFSET"] $base_offset)
 						I_SPARSE_SWITCH_TARGET_COUNT[$start, Integer.toString(targetCount)]
 						^(I_SPARSE_SWITCH_KEYS[$start, "I_SPARSE_SWITCH_KEYS"] fixed_32bit_literal*)
 						^(I_SPARSE_SWITCH_TARGETS $switch_target*))
		->	^(I_STATEMENT_SPARSE_SWITCH[$start, "I_STATEMENT_SPARSE_SWITCH"]
				^(I_SPARSE_SWITCH_BASE_OFFSET[$start, "I_SPARSE_SWITCH_BASE_OFFSET"] $base_offset)
				I_SPARSE_SWITCH_TARGET_COUNT[$start, Integer.toString(targetCount)]
				^(I_SPARSE_SWITCH_KEYS[$start, "I_SPARSE_SWITCH_KEYS"] fixed_32bit_literal*)
				^(I_SPARSE_SWITCH_TARGETS $switch_target*)) 					
	;
	
offset_or_label
	:	OFFSET | LABEL;	


register_list
	:	REGISTER* -> ^(I_REGISTER_LIST[$start, "I_REGISTER_LIST"] REGISTER*);
	
register_range
	:	REGISTER REGISTER? -> ^(I_REGISTER_RANGE[$start, "I_REGISTER_RANGE"] REGISTER REGISTER?);


field_type_descriptor
	:	PRIMITIVE_TYPE
	|	CLASS_DESCRIPTOR
	|	ARRAY_DESCRIPTOR
	;
	
class_or_array_type_descriptor
	:	CLASS_DESCRIPTOR
	|	ARRAY_DESCRIPTOR;
	
type_descriptor
	:	VOID_TYPE
	|	PRIMITIVE_TYPE
	|	CLASS_DESCRIPTOR
	|	ARRAY_DESCRIPTOR
	;	
	
integral_literal
	:	LONG_LITERAL
	|	INTEGER_LITERAL
	|	SHORT_LITERAL
	|	BYTE_LITERAL;	
	
fixed_32bit_literal
	:	INTEGER_LITERAL
	|	LONG_LITERAL
	|	SHORT_LITERAL
	|	BYTE_LITERAL
	|	FLOAT_LITERAL
	|	CHAR_LITERAL
	|	BOOL_LITERAL;
	
fixed_literal returns[int size]
	:	INTEGER_LITERAL {$size = 4;}
	|	LONG_LITERAL {$size = 8;}
	|	SHORT_LITERAL {$size = 2;}
	|	BYTE_LITERAL {$size = 1;}
	|	FLOAT_LITERAL {$size = 4;}
	|	DOUBLE_LITERAL {$size = 8;}
	|	CHAR_LITERAL {$size = 2;}
	|	BOOL_LITERAL {$size = 1;};

literal	:	INTEGER_LITERAL
	|	LONG_LITERAL
	|	FLOAT_LITERAL
	|	DOUBLE_LITERAL
	|	CHAR_LITERAL
	|	STRING_LITERAL
	|	BOOL_LITERAL;