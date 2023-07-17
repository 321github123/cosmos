#!/usr/bin/env python3
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
# -*- coding: latin-1 -*-
"""
telemetry.py
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

import os
from openc3.script import COSMOS

# def tlm(*args, **kwargs):
#     """Poll for the converted value of a telemetry item
#     Usage:
#       tlm(target_name, packet_name, item_name)
#     or
#       tlm('target_name packet_name item_name')
#     """
#     return COSMOS.json_rpc_request("tlm", *args, **kwargs)


# def tlm_raw(*args, **kwargs):
#     """Poll for the raw value of a telemetry item
#     Usage:
#       tlm_raw(target_name, packet_name, item_name)
#     or
#       tlm_raw('target_name packet_name item_name')
#     """
#     return COSMOS.json_rpc_request("tlm_raw", *args, **kwargs)


# def tlm_formatted(*args, **kwargs):
#     """Poll for the formatted value of a telemetry item
#     Usage:
#       tlm_formatted(target_name, packet_name, item_name)
#     or
#       tlm_formatted('target_name packet_name item_name')
#     """
#     return COSMOS.json_rpc_request("tlm_formatted", *args, **kwargs)


# def tlm_with_units(*args, **kwargs):
#     """Poll for the formatted with units value of a telemetry item
#     Usage:
#       tlm_with_units(target_name, packet_name, item_name)
#     or
#       tlm_with_units('target_name packet_name item_name')
#     """
#     return COSMOS.json_rpc_request("tlm_with_units", *args, **kwargs)


# def tlm_variable(*args, **kwargs):
#     return COSMOS.json_rpc_request("tlm_variable", *args, **kwargs)


# def set_tlm(*args, **kwargs):
#     """Set a telemetry point to a given value. Note this will be over written in
#     a live system by incoming new telemetry.
#     Usage:
#       set_tlm(target_name, packet_name, item_name, value)
#     or
#       set_tlm("target_name packet_name item_name = value")
#     """
#     return COSMOS.json_rpc_request("set_tlm", *args, **kwargs)


# def set_tlm_raw(*args, **kwargs):
#     """Set the raw value of a telemetry point to a given value. Note this will
#     be over written in a live system by incoming new telemetry.
#     Usage:
#       set_tlm_raw(target_name, packet_name, item_name, value)
#     or
#       set_tlm_raw("target_name packet_name item_name = value")
#     """
#     return COSMOS.json_rpc_request("set_tlm_raw", *args, **kwargs)


def inject_tlm(
    target_name,
    packet_name,
    item_hash=None,
    value_type="CONVERTED",
    send_routers=True,
    send_packet_log_writers=True,
    create_new_logs=False,
):
    """Injects a packet into the system as if it was received from an interface"""
    return COSMOS.json_rpc_request(
        "inject_tlm",
        target_name,
        packet_name,
        item_hash,
        value_type,
        send_routers,
        send_packet_log_writers,
        create_new_logs,
    )


def override_tlm(*args, **kwargs):
    """Permanently set the converted value of a telemetry point to a given value
    Usage:
      override_tlm(target_name, packet_name, item_name, value)
    or
      override_tlm("target_name packet_name item_name = value")
    """
    return COSMOS.json_rpc_request("override_tlm", *args, **kwargs)


def override_tlm_raw(*args, **kwargs):
    """Permanently set the raw value of a telemetry point to a given value
    Usage:
      override_tlm_raw(target_name, packet_name, item_name, value)
    or
      override_tlm_raw("target_name packet_name item_name = value")
    """
    return COSMOS.json_rpc_request("override_tlm_raw", *args, **kwargs)


def normalize_tlm(*args, **kwargs):
    """Clear an override of a telemetry point
    Usage:
      normalize_tlm(target_name, packet_name, item_name)
    or
      normalize_tlm("target_name packet_name item_name")
    """
    return COSMOS.json_rpc_request("normalize_tlm", *args, **kwargs)


def get_telemetry(target_name, packet_name):
    """
    The get_telemetry function returns a packet hash.
    Usage:
      packet_hash = get_telemetry(target_name, packet_name)
    """
    return COSMOS.json_rpc_request("get_telemetry", target_name, packet_name)


def get_tlm_packet(target_name, packet_name, value_type="CONVERTED"):
    """Gets all the values from the given packet returned in a two dimensional
    array containing the item_name, value, and limits state.
    Usage:
      values = get_tlm_packet(target_name, packet_name, <:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS>)
    """
    return COSMOS.json_rpc_request(
        "get_tlm_packet", target_name, packet_name, type=value_type
    )


def get_tlm_values(items, value_type="CONVERTED"):
    """Gets all the values from the given packet returned in an
    array consisting of an Array of item values, an array of item limits state
    given as symbols such as :RED, :YELLOW, :STALE, an array of arrays including
    the limits setting such as red low, yellow low, yellow high, red high and
    optionally green low and high, and the overall limits state of the system.
    Usage:
      values = get_tlm_values([[target_name, packet_name, item_name], ...], <:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS>)
    """
    return COSMOS.json_rpc_request("get_tlm_values", items)


def get_target(target_name):
    """
    The get_target method returns a target hash containing all the information about the target.
    """
    return COSMOS.json_rpc_request("get_target", target_name)


def get_target_list():
    """Gets the list of all defined targets."""
    return COSMOS.json_rpc_request("get_target_list")


def get_tlm_buffer(target_name, packet_name):
    """The get_tlm_buffer method returns the raw packet buffer as a Ruby string.
    Syntax:
      buffer = get_tlm_buffer("<Target Name>", "<Packet Name>")
    """
    return COSMOS.json_rpc_request("get_tlm_buffer", target_name, packet_name)


def subscribe_packets(packets: list):
    """The subscribe_packets method allows the user to listen for one or more telemetry packets of data to arrive. A unique id is returned which is used to retrieve the data.
    Syntax:
        id = subscribe_packets([['INST', 'HEALTH_STATUS'], ['INST', 'ADCS']])
    """
    return COSMOS.json_rpc_request("subscribe_packets", packets)
