#!/usr/bin/env python3
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
# -*- coding: latin-1 -*-
"""
connection.py
"""

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
#
# This file may also be used under the terms of a commercial license
# if purchased from OpenC3, Inc.

from contextlib import ContextDecorator
import json
import logging
from requests import Session
from requests.auth import AuthBase
from threading import RLock, Event, Thread
import requests

from openc3.__version__ import __title__
from .authorization import generate_auth
from openc3.environment import *
from .exceptions import CosmosConnectionError
from .decorators import request_wrapper
from openc3.json_rpc import CosmosJsonRpcRequest, CosmosJsonRpcResponse
from .exceptions import CosmosError

LOGGER = logging.getLogger(__title__)


class CosmosConnection(ContextDecorator):
    """Class to perform JSON-RPC Calls to the COSMOS Server (or other JsonDrb server)

    The CosmosConnection can be used to call COSMOS server methods directly:
      server = CosmosConnection(hostname: "127.0.0.1", port: 7777)
      server.write(...)
    """

    def __init__(
        self,
        schema: str = OPENC3_API_SCHEMA,
        hostname: str = OPENC3_API_HOSTNAME,
        port: int = OPENC3_API_PORT,
        timeout: float = 5.0,
        auth: AuthBase = None,
    ) -> None:
        """Constructor

        Parameters:
        hostname -- The name of the machine which has started the JSON service
        port -- The port number of the JSON service
        timeout -- The amount of time the socket will read until an error
        """
        self.id = 0
        self.timeout = float(timeout)
        self.request_url = f"{schema}://{hostname}:{port}"
        self._session = Session()
        self._session.headers = {
            "User-Agent": OPENC3_USER_AGENT,
        }
        self.auth = generate_auth() if auth is None else auth
        self._mutex = RLock()
        self._shutdown_needed = Event()

    def shutdown(self):
        """Permanently disconnects from the JSON server"""
        self._shutdown_needed.set()
        self._session.close()

    def update_kwargs(self, request_kwargs: dict):
        request_kwargs["auth"] = self.auth
        params = request_kwargs.get("params", {})
        if "scope" not in params:
            params["scope"] = OPENC3_SCOPE
        request_kwargs["params"] = params

    def json_rpc_request(self, method_name, *args, **kwargs):
        """Forwards all method calls to the remote service.

        method_name -- Name of the method to call
        args -- Array of parameters to pass to the method
        kwargs -- Dict of parameters to pass to the method
        return -- The result of the method call. If something goes wrong with the
          protocol a exception extended from RuntimeError is raised.
        """
        if self._shutdown_needed.is_set():
            raise CosmosConnectionError("shutdown event is set, exiting")
        with self._mutex:
            self.id += 1
            # if "scope" not in args and "scope" not in kwargs:
            #     kwargs["scope"] = OPENC3_SCOPE
            json_rpc_request = CosmosJsonRpcRequest(
                self.id, method_name, *args, **kwargs
            )
            resp = self._make_json_rpc_request(json_rpc_request.to_hash())
            try:
                json_rpc_response = CosmosJsonRpcResponse.from_bytes(resp.content)
                LOGGER.debug(
                    "response %s %s", type(json_rpc_response), json_rpc_response
                )
                return json_rpc_response.result
            except AttributeError:
                return json_rpc_response

    @request_wrapper
    def _make_json_rpc_request(self, hash_: dict):
        """Use the python requests libary to send the request to Cosmos.

        This is an internal method that uses two decorators. request_wrapper
        captures errors from the request libary.
        return -- bytes: request.content
            https://docs.python-requests.org/en/master/user/quickstart/#binary-response-content
        """
        request_kwargs = {
            "auth": self.auth,
            "url": f"{self.request_url}/openc3-api/api",
            "data": json.dumps(hash_),
            "headers": {
                "Content-Type": "application/json-rpc",
            },
        }
        LOGGER.debug("calling with %s", request_kwargs)
        resp = self._session.post(**request_kwargs)
        LOGGER.debug(
            "resp: %s total_seconds: %f content: %s",
            resp,
            resp.elapsed.total_seconds(),
            resp.content,
        )
        return resp

    @request_wrapper
    def get(self, endpoint: str, **kwargs):
        """Use the python requests libary to send the request to Cosmos.

        This is an internal method that uses two decorators. request_wrapper
        captures errors from the request libary.
        return -- bytes: request.content
            https://docs.python-requests.org/en/master/user/quickstart/#binary-response-content
        """
        kwargs["url"] = f"{self.request_url}{endpoint}"
        self.update_kwargs(kwargs)
        LOGGER.debug("calling with %s", kwargs)
        resp = requests.get(**kwargs)
        LOGGER.debug(
            "resp: %s total_seconds: %f content: %s",
            resp,
            resp.elapsed.total_seconds(),
            resp.content,
        )
        resp.raise_for_status()
        return resp

    @request_wrapper
    def post(self, endpoint: str, **kwargs):
        """Use the python requests libary to send the request to Cosmos.

        This is an internal method that uses two decorators. request_wrapper
        captures errors from the request libary.
        return -- bytes: request.content
            https://docs.python-requests.org/en/master/user/quickstart/#binary-response-content
        """
        kwargs["url"] = f"{self.request_url}{endpoint}"
        self.update_kwargs(kwargs)
        LOGGER.debug("calling with %s", kwargs)
        resp = requests.post(**kwargs)
        LOGGER.debug(
            "resp: %s total_seconds: %f content: %s",
            resp,
            resp.elapsed.total_seconds(),
            resp.content,
        )
        resp.raise_for_status()
        return resp

    @request_wrapper
    def put(self, endpoint: str, **kwargs):
        """Use the python requests libary to send the request to Cosmos.

        This is an internal method that uses two decorators. request_wrapper
        captures errors from the request libary.
        return -- bytes: request.content
            https://docs.python-requests.org/en/master/user/quickstart/#binary-response-content
        """
        kwargs["url"] = f"{self.request_url}{endpoint}"
        self.update_kwargs(kwargs)
        LOGGER.debug("calling with %s", kwargs)
        resp = requests.put(**kwargs)
        LOGGER.debug(
            "resp: %s total_seconds: %f content: %s",
            resp,
            resp.elapsed.total_seconds(),
            resp.content,
        )
        resp.raise_for_status()
        return resp

    @request_wrapper
    def delete(self, endpoint: str, **kwargs):
        """Use the python requests libary to send the request to Cosmos.

        This is an internal method that uses two decorators. request_wrapper
        captures errors from the request libary.
        return -- bytes: request.content
            https://docs.python-requests.org/en/master/user/quickstart/#binary-response-content
        """
        kwargs["url"] = f"{self.request_url}{endpoint}"
        self.update_kwargs(kwargs)
        LOGGER.debug("calling with %s", kwargs)
        resp = requests.delete(**kwargs)
        LOGGER.debug(
            "resp: %s total_seconds: %f content: %s",
            resp,
            resp.elapsed.total_seconds(),
            resp.content,
        )
        resp.raise_for_status()
        return resp
