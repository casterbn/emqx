%%--------------------------------------------------------------------
%% Copyright (c) 2022-2024 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_bridge_s3_upload).

-include_lib("typerefl/include/types.hrl").
-include_lib("hocon/include/hoconsc.hrl").
-include("emqx_bridge_s3.hrl").

-define(ACTION, ?ACTION_UPLOAD).

-behaviour(hocon_schema).
-export([
    namespace/0,
    roots/0,
    fields/1,
    desc/1
]).

-export([
    bridge_v2_examples/1
]).

%%-------------------------------------------------------------------------------------------------
%% `hocon_schema' API
%%-------------------------------------------------------------------------------------------------

namespace() ->
    "bridge_s3".

roots() ->
    [].

fields(Field) when
    Field == "get_bridge_v2";
    Field == "put_bridge_v2";
    Field == "post_bridge_v2"
->
    emqx_bridge_v2_schema:api_fields(Field, ?ACTION, fields(?ACTION));
fields(action) ->
    {?ACTION,
        hoconsc:mk(
            hoconsc:map(name, hoconsc:ref(?MODULE, ?ACTION)),
            #{
                desc => <<"S3 Upload Action Config">>,
                required => false
            }
        )};
fields(?ACTION) ->
    emqx_bridge_v2_schema:make_producer_action_schema(
        hoconsc:mk(
            ?R_REF(s3_upload_parameters),
            #{
                required => true,
                desc => ?DESC(s3_upload)
            }
        ),
        #{
            resource_opts_ref => ?R_REF(s3_action_resource_opts)
        }
    );
fields(s3_upload_parameters) ->
    emqx_s3_schema:fields(s3_upload) ++
        [
            {content,
                hoconsc:mk(
                    emqx_schema:template(),
                    #{
                        required => false,
                        default => <<"${.}">>,
                        desc => ?DESC(s3_object_content)
                    }
                )}
        ];
fields(s3_action_resource_opts) ->
    UnsupportedOpts = [batch_size, batch_time],
    lists:filter(
        fun({N, _}) -> not lists:member(N, UnsupportedOpts) end,
        emqx_bridge_v2_schema:action_resource_opts_fields()
    ).

desc(s3) ->
    ?DESC(s3_upload);
desc(Name) when
    Name == s3_upload;
    Name == s3_upload_parameters
->
    ?DESC(Name);
desc(s3_action_resource_opts) ->
    ?DESC(emqx_resource_schema, resource_opts);
desc(_Name) ->
    undefined.

%% Examples

bridge_v2_examples(Method) ->
    [
        #{
            <<"s3">> => #{
                summary => <<"S3 Simple Upload">>,
                value => s3_upload_action_example(Method)
            }
        }
    ].

s3_upload_action_example(post) ->
    maps:merge(
        s3_upload_action_example(put),
        #{
            type => atom_to_binary(?ACTION_UPLOAD),
            name => <<"my_s3_action">>
        }
    );
s3_upload_action_example(get) ->
    maps:merge(
        s3_upload_action_example(put),
        #{
            status => <<"connected">>,
            node_status => [
                #{
                    node => <<"emqx@localhost">>,
                    status => <<"connected">>
                }
            ]
        }
    );
s3_upload_action_example(put) ->
    #{
        enable => true,
        connector => <<"my_s3_connector">>,
        description => <<"My action">>,
        parameters => #{
            bucket => <<"${clientid}">>,
            key => <<"${topic}">>,
            content => <<"${payload}">>,
            acl => <<"public_read">>
        },
        resource_opts => #{
            query_mode => <<"sync">>,
            inflight_window => 10
        }
    }.
