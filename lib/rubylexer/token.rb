=begin legal crap
    rubylexer - a ruby lexer written in ruby
    Copyright (C) 2004,2005,2008  Caleb Clausen

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
=end



class RubyLexer
#-------------------------
class Token
   attr_accessor :ident
   def to_s
     @ident || "<#{self.class.name}>"
   end
   attr_accessor :offset #file offset of start of this token
   attr_accessor :as #if defined, a KeywordToken which this token stands in for.
   attr_accessor :allow_ooo_offset #hack

   def initialize(ident,offset=nil)
      @ident=ident
      @offset=offset
   end
   
   def error; end

   def has_no_block?; false end

   attr_accessor :tag
end

#-------------------------
class WToken< Token
   def ===(pattern)
      assert @ident
      pattern===@ident
   end
end

#-------------------------
class KeywordToken < WToken   #also some operators

  #-----------------------------------
  def set_callsite!(x=true)
    @callsite=x
  end

  #-----------------------------------
  def callsite? 
    @callsite if defined? @callsite
  end


  #-----------------------------------
  def set_infix! 
    @infix=true
  end

  #-----------------------------------
  def infix? 
    @infix ||= nil
  end
  def prefix?; !infix? end

  #-----------------------------------
  def has_end!
    @has_end=true
  end

  #-----------------------------------
  def has_end?
    self===RubyLexer::BEGINWORDS and @has_end||=nil
  end

  attr_accessor :ternary, :grouping

  def has_no_block!
     @has_no_block=true
  end

  def has_no_block?
     @has_no_block if defined? @has_no_block
  end

  def infix
    @infix if defined? @infix
  end
end

#-------------------------
class OperatorToken < WToken
  attr_accessor :unary
  alias prefix? unary
  def infix?; !prefix? end

end


#-------------------------
module TokenPat
   @@TokenPats={}
   def token_pat #used in various case statements...
     result=self.dup
     @@TokenPats[self] ||=
       (class <<result
         alias old_3eq ===
         def ===(token)
           WToken===token and old_3eq(token.ident)
         end
       end;result)
   end
end

class ::String; include TokenPat; end
class ::Regexp; include TokenPat; end

#-------------------------
class VarNameToken < WToken
  attr_accessor :lvar_type
  attr_accessor :in_def
end

#-------------------------
class NumberToken < Token
  def to_s; @ident.to_s end
  def negative; /\A-/ === ident end
end

#-------------------------
class SymbolToken < Token
  attr_accessor :open,:close
  attr :raw
  def initialize(ident,offset=nil,starter=':')
    @raw=ident
    str=ident.to_s
    str[0,2]='' if /\A%s/===str
    super starter+str, offset
    @open=":"
    @close=""
#   @char=':'

  end

  def to_s
    return @ident
=begin
    raw=@raw.to_s
    raw=raw[1...-1] if StringToken===@raw
    @open+raw+@close 
=end
  end
end

#-------------------------
class MethNameToken  < Token # < SymbolToken
   def initialize(ident,offset=nil,bogus=nil)
      @ident= (VarNameToken===ident)? ident.ident : ident
      @offset=offset
      @has_no_block=false
   #   @char=''
   end

   def [](regex) #is this used?
      regex===ident
   end
   def ===(pattern)
      pattern===@ident
   end

   def has_no_block!
     @has_no_block=true
   end

   def has_no_block?
     @has_no_block
   end

   def has_equals; /[a-z_0-9]=$/i===ident end
end

#-------------------------
class NewlineToken < Token
   def initialize(nlstr="\n",offset=nil)
      super(nlstr,offset)
      #@char=''
   end
   def as; ';' end
end

#-------------------------
class StringToken < Token
   attr :char

   attr_accessor :modifiers    #for regex only
   attr_accessor :elems
   attr_accessor :startline
   attr_accessor :line  #line on which the string ENDS
   attr_accessor :bs_handler

   attr_accessor :open #exact sequence of chars used to start the str
   attr_accessor :close #exact seq of (1) char to stop the str
   
   def with_line(line)
     @line=line
     self
   end

   def initialize(type='"',ident='')
      super(ident)
      type=="'" and type='"'
      @char=type
      assert @char[/^[\[{"`\/]$/]  #"
      @elems=[ident.dup]     #why .dup?
      @modifiers=nil
      @line=nil
   end

   DQUOTE_ESCAPE_TABLE = [
     ["\n",'\n'],
     ["\r",'\r'],
     ["\t",'\t'],
     ["\v",'\v'],
     ["\f",'\f'],
     ["\e",'\e'],
     ["\b",'\b'],
     ["\a",'\a']
   ]
   PREFIXERS={ '['=>"%w[", '{'=>'%W{' }
   SUFFIXERS={ '['=>"]",   '{'=>'}' }

   def has_str_inc?
     elems.size>1 or RubyCode===elems.first
   end

   def to_s transname=:transform
      assert @char[/[\[{"`\/]/] #"
      #on output, all single-quoted strings become double-quoted
      assert(@elems.length==1)  if @char=='['

      result=open.dup
      starter=result[-1,1]
      ender=close
      elems.each{|e|
        case e
        when String; result<<e
#        strfrag=translate_escapes strfrag if RubyLexer::FASTER_STRING_ESCAPES
#        result << send(transname,strfrag,starter,ender)
        when VarNameToken;
          if /^[$@]/===e.to_s
            result << '#' + e.to_s
          else 
            result << "\#{#{e}}"
          end
        when RubyCode; result << '#' + e.to_s
        else fail
        end
      }
      result << ender

      if @char=='/'
        result << modifiers if modifiers #regex only
        result="%r"+result if RubyLexer::WHSPLF[result[1,1]]
      end

      return result
   end

   def to_term
      result=[]
      0.step(@elems.length-1,2) { |i|
         result << ConstTerm.new(@elems[i].dup)

         if e=@elems[i+1]
            assert(e.kind_of?(RubyCode))
            result << (RubyTerm.new e)
         end
      }
      return result
   end

   def append(glob)
      #assert @elems.last.kind_of?(String)
      case glob
      when String,Integer then append_str! glob
      when RubyCode then append_code! glob
      else raise "bad string contents: #{glob}, a #{glob.class}"
      end
      #assert @elems.last.kind_of?(String)
   end

   def append_token(strtok)
      assert @elems.last.kind_of?(String)
      #assert strtok.elems.last.kind_of?(String)
      assert strtok.elems.first.kind_of?(String)

      @elems.last << strtok.elems.shift

      first=strtok.elems.first
      assert( first.nil? || first.kind_of?(RubyCode) )

      @elems += strtok.elems
      @ident << strtok.ident

      assert((!@modifiers or !strtok.modifiers))
      @modifiers||=strtok.modifiers

      #assert @elems.last.kind_of?(String)

      @bs_handler ||=strtok.bs_handler

      return self
   end

   def translate_escapes(str)
     rl=RubyLexer.new("(string escape translation hack...)",'')
     result=str.dup
     seq=result.to_sequence
     rl.instance_eval{@file=seq}
     repls=[]
     i=0
     #ugly ugly ugly
     while i<result.size and bs_at=result.index(/\\./m,i) 
         seq.pos=$~.end(0)-1
         ch=rl.send(bs_handler,"\\",@open[-1,1],@close)
         result[bs_at...seq.pos]=ch
         i=bs_at+ch.size
     end

     return  result
   end

private
   UNESC_DELIMS={}

   #simpler transform, preserves original exactly
   def simple_transform(strfrag,starter,ender)
      assert('[{/'[@char])
      #strfrag.gsub!(/(\A|[^\\])(?:\\\\)*\#([{$@])/){$1+'\\#'+$2} unless @char=='['
      delimchars=Regexp.quote starter+ender
      delimchars+=Regexp.quote("#") unless @char=='['  #escape beginning of string iterpolations

      #i think most or all of this method is useless now...

      #escape curly brace in string interpolations (%W only)
      strfrag.gsub!('#{', '#\\{') if @char=='{'

      ckey=starter+ender
      unesc_delim=
        UNESC_DELIMS[ckey]||=
          /(\A|[^\\](?:\\\\)*)([#{delimchars}]+)/
#          /(\\)([^#{delimchars}#{RubyLexer::WHSPLF}]|\Z)/
      
      #an even number (esp 0) of backslashes before delim becomes escaped delim
      strfrag.gsub!(unesc_delim){ 
        pre=$1; toesc=$2
        pre+toesc.gsub(/(.)/){ "\\"+$1 }
      }

      #no need to double backslashes anymore... they should come pre-doubled

      return strfrag
   end

   def transform(strfrag,starter,ender)
      strfrag.gsub!("\\",'\\'*4)
      strfrag.gsub!(/#([{$@])/,'\\#\\1')
      strfrag.gsub!(Regexp.new("[\\"+starter+"\\"+ender+"]"),'\\\\\\&') unless @char=='?'
      DQUOTE_ESCAPE_TABLE.each {|pair|
         strfrag.gsub!(*pair)
      } unless @char=='/'
      strfrag.gsub!(/[^ -~]/){|np| #nonprintables
         "\\x"+sprintf('%02X',np[0])
      }
      #break up long lines (best done later?)
      strfrag.gsub!(/(\\x[0-9A-F]{2}|\\?.){40}/i, "\\&\\\n")
      return strfrag
   end

   def append_str!(str)
      if @elems.last.kind_of?(String)
        @elems.last << str
      else
        @elems << str
      end
      @ident << str
      assert @elems.last.kind_of?(String)
   end

   def append_code!(code)
      if @elems.last.kind_of?(String)
      else
        @elems.push ''
      end
      @elems.push code,''
      @ident <<  "\#{#{code}}"
      assert @elems.last.kind_of?(String)
   end
end

#-------------------------
class RenderExactlyStringToken < StringToken
   alias transform simple_transform
end

#-------------------------
class HerePlaceholderToken < WToken
   attr_reader :termex, :quote, :ender, :dash
   attr_accessor :unsafe_to_use, :string
   attr_accessor :bodyclass
   attr_accessor :open, :close

   def initialize(dash,quote,ender,quote_real=true)
      @dash,@quote,@ender,@quote_real=dash,quote,ender,quote_real
      @unsafe_to_use=true
      @string=StringToken.new

      #@termex=/^#{'[\s\v]*' if dash}#{Regexp.escape ender}$/
      @termex=Regexp.new \
         ["^", ('[\s\v]*' if dash), Regexp.escape(ender), "$"].to_s
      @bodyclass=HereBodyToken
   end

   def ===(bogus); false end

   def to_s
#      if @bodyclass==OutlinedHereBodyToken
        result=if/[^a-z_0-9]/i===@ender
          @ender.gsub(/[\\"]/, '\\\\'+'\\&')
        else
          @ender
        end
        return ["<<",@dash,@quote_real&&@quote,result,@quote_real&&@quote].to_s
#      else
#        assert !unsafe_to_use
#        return @string.to_s
#      end
   end

   def append s; @string.append s end

   def append_token tok; @string.append_token tok  end
   
   #def with_line(line) @string.line=line; self end
   
   def line; @string.line end
   def line=line; @string.line=line end

end

#-------------------------
module StillIgnoreToken 

end

#-------------------------
class IgnoreToken < Token
  include StillIgnoreToken
end

#-------------------------
class WsToken < IgnoreToken
end

#-------------------------
class ZwToken < IgnoreToken
  def initialize(offset)
    super('',offset)
  end
  def explicit_form
    abstract
  end
  def explicit_form_all; explicit_form end
end

#-------------------------
class NoWsToken < ZwToken
  def explicit_form_all
    "#nows#"
  end
  def explicit_form
    nil
  end
end

#-------------------------
class ImplicitParamListStartToken < KeywordToken
  include StillIgnoreToken
  def initialize(offset)
    super("(",offset)
  end
  def to_s; '' end
  def as; "(" end
end

#-------------------------
class ImplicitParamListEndToken < KeywordToken
  include StillIgnoreToken
  def initialize(offset)
    super(")",offset)
  end
  def to_s; '' end
  def as; ")" end
end

#-------------------------
class AssignmentRhsListStartToken < ZwToken
  def explicit_form
    '*['
  end
end

#-------------------------
class AssignmentRhsListEndToken < ZwToken
  def explicit_form
    ']'
  end
end

#-------------------------
class KwParamListStartToken  < ZwToken
  def explicit_form_all
    "#((#"
  end
  def explicit_form
    nil
  end
end

#-------------------------
class KwParamListEndToken  < ZwToken
  def explicit_form_all
    "#))#"
  end
  def explicit_form
    nil
  end
end

#-------------------------
class EndHeaderToken < ZwToken
  def as; ";" end
end
EndDefHeaderToken=EndHeaderToken

#-------------------------
class EscNlToken < IgnoreToken
   def initialize(filename,linenum,ident="\\\n",offset=nil)
      super(ident,offset)
      #@char='\\'
      @filename=filename
      @linenum=linenum
   end
end

#-------------------------
class EoiToken < Token
   attr :file
   alias :pos :offset

   def initialize(cause,file, offset=nil)
      super(cause,offset)
      @file=file
   end
end

#-------------------------
class HereBodyToken < IgnoreToken
  #attr_accessor :ender
  attr_accessor :open,:close
  def initialize(headtok,linecount)
    assert HerePlaceholderToken===headtok
    super(headtok.string,headtok.string.offset)
    @headtok=headtok
    @linecount=linecount
  end

  def line
    @ident.line
  end

  def to_s
    @ident.to_s
  end

  attr :headtok
  attr :linecount #num lines here body spans (including terminator)
end

#-------------------------
class FileAndLineToken < IgnoreToken
   attr_accessor :line

   def initialize(ident,line,offset=nil)

      super ident,offset
      #@char='#'
      @line=line
   end

   #def char; '#' end

   def to_s()
      ['#', @ident, ':', @line].to_s
   end

   def file()   @ident   end
   def subitem()   @line   end #needed?
end

#-------------------------
class OutlinedHereBodyToken < HereBodyToken
  def to_s
    assert HerePlaceholderToken===@headtok
    result=@headtok.string
    result=result.to_s(:simple_transform).match(/^"(.*)"$/m)[1]
    return result +
           @headtok.ender +
           "\n"
  end
end

#-------------------------
module ErrorToken
  attr_accessor :error
end

#-------------------------
class SubitemToken < Token
   attr :char2
   attr :subitem

   def initialize(ident,subitem)
      super ident
      @subitem=subitem
   end

   def to_s()
      super+@char2+@subitem.to_s
   end
end


#-------------------------
class DecoratorToken < SubitemToken
   def initialize(ident,subitem)
      super '^'+ident,subitem
      @subitem=@subitem.to_s  #why to_s?
      #@char='^'
      @char2='='
   end

   #alias to_s ident  #parent has right implementation of to_s... i think
   def needs_value?()   @subitem.nil?   end

   def value=(v)   @subitem=v  end
   def value()     @subitem    end
end

end

require "rubylexer/rubycode"

