%%
%% Demonstrates how to process the auth-token which is sent by a client as
%% part of the LOGIN process.
%%
%% author
%%  Torben K�nke
%%
-module(dumm).
-import(pbkdf2, [pbkdf2/4]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0]).

%%
%% The entry-point.
%%
start() ->
	% Sample auth-token, generated by authentication server.
	AuthToken = "FbMxM0WW/GGYurBiiTbabJdu+a/LcM5LxpJdlwH63L9BGlec9MWA6vWlLngjEno5VV11vt0zeN5zJeiRtMhskq19zvfA",
	
	verify_auth_token(AuthToken)
	% TODO: The gameserver should cache recent auth-tokens and reject auth-tokens
	%       if they are already in the recent-token-cache to prevent
	%       replay-attacks.
.

%%
%% verify_auth_token - Verifies the specified auth-token.
%%
%% AuthToken
%%  The auth-token to verify.
%% Return
%%  true if the auth-token is valid; Otherwise false.
%%
verify_auth_token(AuthToken) ->
	% Configuration values.
	% In reality, these should be stored in a configuration file and _must_ be
	% in sync with the corresponding values of the authentication server!
	{SharedSecretKey, SaltSize, IVSize, Iterations, AESKeySize, Transform} =
		{"SuperGeheim", 24, 16, 1000, 16, aes_ctr},
	% 1. Base64-decode the auth-token.
	Data = base64:decode(AuthToken),
	% 2. Extract the prepended salt and IV from the data.
	<<Salt:SaltSize/binary, IV:IVSize/binary, Rest/binary>> = Data,
	% 3. Derive the encryption key from the shared secret-key and the salt.
	{ok, AESKey} = pbkdf2:pbkdf2(sha, SharedSecretKey, Salt, Iterations, AESKeySize),
	% 4. Decrypt the data.
	State = crypto:stream_init(Transform, AESKey, IV),
	{_, DecryptedBinary} = crypto:stream_decrypt(State, Rest),
	DecryptedAuthToken = binary:bin_to_list(DecryptedBinary),
	% DecryptedAuthToken is the decrypted auth-token and is of the form
	% User:Entity:Timestamp.
	% 5. Split token into its individual parts.
	[User, Entity, Ts] = string:tokens(DecryptedAuthToken, ":"),
	% 6. TODO: Verify User and Entity are actually the same as the ones sent
	%          by the client as part of the LOGIN message.
	% .... 
	% ....
	io:format(["Auth-Token components: User='", User, "', Entity='", Entity
			  ,"', Timestamp='", Ts ,"'\n"]),

	% 7. Verify timestamp is within a reasonable threshold.
	%    TODO: What's a good threshold value?
	{Timestamp, _} = string:to_integer(Ts),
	CurrentTime = get_unix_time(),
	DiffTime = CurrentTime - Timestamp,
	if
		% Timestamp is older than 100 seconds.
		DiffTime > 100 ->
			false
		;
		true ->
			true
	end	
.

%
% Returns the current time as the number of seconds that have passed since
% 01.01.1970.
%
get_unix_time() ->
	{Mega, Secs, _} = now(),
	Mega * 1000000 + Secs
.
