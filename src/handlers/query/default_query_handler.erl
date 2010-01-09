% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2009 Rusty Klophaus
% See MIT-LICENSE for licensing information.

% Though this is defined as a handler, it is unlikely
% that anyone would want to override the default behaviour. 
% It is defined as a handler simply because it fit well 
% into the existing handler pattern.

-module (default_query_handler).
-behaviour (query_handler).
-include ("wf.inc").
-export ([
	init/1, 
	finish/1,
	get_value/2
]).

init(_State) -> 
	% Get query params and post params
	% from the request bridge...
	RequestBridge = wf_context:request_bridge(),
	QueryParams = RequestBridge:query_params(),
	PostParams = RequestBridge:post_params(),

	% Load into state...
	Params = QueryParams ++ PostParams,
	
	% Pre-normalize the parameters.
	Params1 = [normalize_param(X) || X <- Params],
	{ok, Params1}.
	
finish(_State) -> 
	% Clear out the state.
	{ok, []}.
	
%% Given a path, return the value that matches the path.
get_value(Path, State) ->
	Params = State,
	Path1 = normalize_path(Path),
	?PRINT(Path1),
	?PRINT(State),
	
	% First, get all params whose first element equals the 
	% first element of the path we are looking for. In the process,
	% take the tail of the paths.
	Params1 = [{tl(P), V} || {P, V} <- Params, hd(P) == hd(Path1)],

	% Call refine_params/2 to further refine our search.
	Matches = refine_params(tl(Path1), Params1),
	case Matches of
		[] -> undefined;
		[One] -> One;
		_Many -> throw({?MODULE, too_many_matches, Path})
	end.
	
%% Next, narrow down the parameters by keeping only the parameters
%% that contain the next element found in path, while shrinking the 
%% parameter paths at the same time.
%% For example, if:
%% 	Path   = [a, b, c] 
%% 	Params = [{[x, a, y, b, c], _}] 
%% Then after the first round of refine_params/2 we would have:
%%   Path   = [b, c]
%%   Params = [y, b, c]
refine_params([], Params) -> 
	[V || {_, V} <- Params];
refine_params([H|T], Params) ->
	F = fun({Path, Value}, Acc) ->
		case split_on(H, Path) of
			[] -> Acc;
			RemainingPath -> [{RemainingPath, Value}|Acc]
		end
	end,
	Params1 = lists:foldl(F, [], Params),
	refine_params(T, lists:reverse(Params1)).
	
split_on(_,  []) -> [];
split_on(El, [El|T]) -> T;
split_on(El, [_|T]) -> split_on(El, T).
	
%% Path will be a dot separated list of identifiers.
%% Split and reverse.
normalize_param({Path, Value}) ->
	{normalize_path(Path), Value}.
	
normalize_path(Path) when is_atom(Path) ->
	normalize_path(atom_to_list(Path));
	
normalize_path(Path) when ?IS_STRING(Path) ->
	Tokens = string:tokens(Path, "."),
	Tokens1 = [strip_wfid(X) || X <- Tokens],
	lists:reverse(Tokens1).

%% Most tokens will start with "wfid_". Strip this out.
strip_wfid(Path) ->
	case Path of 
		"wfid_" ++ S -> S;
		S -> S
	end.
	
	