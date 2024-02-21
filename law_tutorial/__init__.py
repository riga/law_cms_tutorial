# coding: utf-8

"""
Tutorial entry point.
"""

import law  # type: ignore


# the crab and htcondor workflow implementations are part of law "contrib" packages
# so we need to explicitly load them, plus some others
law.contrib.load("cms", "gfal", "git", "htcondor", "tasks", "wlcg")
