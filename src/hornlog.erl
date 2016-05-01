%%
%%   Copyright (c) 2016, Dmitry Kolesnikov
%%   All Rights Reserved.
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.
%%
-module(hornlog).

-export([
   head/2, like/2, id/2, id/1,
   rule/2, 
   rule/1,
   c/2, 
   q/2, q/3
]).

%%
%% data types
-type head()    :: _.
-type pattern() :: [_].
-type rule()    :: _.


%%
%% define head of rule by curring argument(s) to the function
-spec head(function(), [_]) -> head().
-spec like(function(), [_]) -> head().

head(Fun, List) ->
   curry(
      lens:get(flens(), lens:pair(module), Fun),
      lens:get(flens(), lens:pair(name),   Fun),
      List
   ).

like(Fun, List) ->
   curry2(
      lens:get(flens(), lens:pair(module), Fun),
      lens:get(flens(), lens:pair(name),   Fun),
      List
   ).

%%
%% identity head, curry argument to identity function
-spec id(_) -> head().

id(X) ->
   head(fun hornlog:id/2, [X]).

id(X, Y) ->
   {X, Y}.


%%
%% define new rule
-spec rule(head(), pattern()) -> rule().
-spec rule(pattern()) -> rule().

rule(Head, Pattern)
 when is_list(Pattern) ->
   Nary = length(Pattern),
   Wary = length([X || X <- Pattern, X =/= '_']),
   % estimate it arity and weighted arity (number of 'explicit' term match)
   {{Nary, Wary}, Pattern, Head};

rule(Head, Pattern) ->
   rule(Head, [Pattern]).

rule(Pattern)
 when is_list(Pattern) ->
   %% bind identity function to rule head 
   rule({var, 0, 'X'}, Pattern);

rule(Pattern)
 when is_binary(Pattern) ->
   %% bind identity function to binary suffix 
   rule({var, 0, 'Y'}, Pattern).


%%
%% compile rules and load its executable code to code server
-spec c(atom(), [rule()]) -> {module, atom()}.

c(Id, Rules) ->
   {ok, Id, Bin} = compile:forms(unit(Id, Rules), []),
   code:load_binary(Id, undefined, Bin).

%%
%% evaluate rules, throws exception if evaluation is failed
-spec q(atom(), pattern()) -> _.
-spec q(atom(), pattern(), _) -> _.

q(Id, Pattern, X) ->
   erlang:apply(Id, q, [X | Pattern]).

q(Id, Pattern) ->
   erlang:apply(Id, q, [Pattern]).

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% transform rules to compilable form (code unit)  
unit(Id, Rules) ->
   [  
      {attribute, 0, module, Id}
     ,{attribute, 0, compile, export_all}
     |rule_match_function(
         rule_roll_up_arity(
            rule_sort_by_arity(Rules)
         )
      )
   ] ++ [{eof, 0}].


%%
%% transform rule to match function(s)
rule_match_function([Head | Tail]) ->
   [pattern_match(Head) | rule_match_function(Tail)];

rule_match_function([]) ->
   [].

pattern_match([{{Nary, _}, _, _} | _] = Rules) ->
   {function, 0, q, Nary + 1,
      lists:map(
         fun({_, Pattern, Head}) ->
            match(Pattern, Head)
         end,
         Rules
      )
   }.


%%
%% roll-up rules with same arity to single code block
rule_roll_up_arity([]) ->
   [];
rule_roll_up_arity(Rules) ->
   N = lens:get(lens:hd(), lens:t1(), lens:t1(), Rules),
   {Head, Tail} = lists:splitwith(
      fun(X) ->
         N =:= lens:get(lens:t1(), lens:t1(), X)
      end,
      Rules
   ),
   [Head | rule_roll_up_arity(Tail)].


%%
%% sort rules by it arity
%% (by number of terms and number of fixed terms) 
rule_sort_by_arity(Rules) ->
   lists:sort(
      fun(A, B) ->
         erlang:element(1, A) >= erlang:element(1, B)
      end,
      Rules
   ).

%% 
%% read only lens to focus on function meta-data
flens() ->
   fun(Fun, Function) ->
      lens:fmap(fun(_) -> Function end, Fun( erlang:fun_info(Function) ))
   end.

%%
%% curry external function
curry(Mod, Fun, List) ->
   {call, 0,
      {remote, 0, {atom, 0, Mod}, {atom, 0, Fun}},
      [erl_parse:abstract(X) || X <- List] ++ [{var, 0, 'X'}]
   }.

curry2(Mod, Fun, List) ->
   {call, 0,
      {remote, 0, {atom, 0, Mod}, {atom, 0, Fun}},
      [erl_parse:abstract(X) || X <- List] ++ [{var, 0, 'X'},{var, 0, 'Y'}]
   }.

%%
%% return pattern match clause
match(Pattern, Body) ->
   {clause, 0,  
      [{var, 0, 'X'}|lists:map(fun match/1, Pattern)], 
      [],
      [Body]
   }.

match('_') ->
   {var, 0, '_'};
match(X)
 when is_binary(X) ->
   {bin, 0, List} = erl_parse:abstract(X),
   {bin, 0, List ++ [{bin_element, 0, {var, 0, 'Y'}, default, [binary]}]};
match(X)   ->
   erl_parse:abstract(X).

