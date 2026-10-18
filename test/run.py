"""Headless checks of Chain Logistics: python test/run.py [CASE [TICKS]] | --changed | --all"""
from factorio_paths import main

main(__file__, {"chl-hop": 520, "chl-request": 1520, "chl-priority": 2420, "chl-trash": 920, "chl-bots": 2420,
                "chl-attach": 30, "chl-tiers": 1020, "chl-quality": 1020, "chl-pulley": 1720, "chl-address": 1520,
                "chl-loader": 2420, "chl-names": 30, "chl-ride": 1520, "chl-belt-tiers": 720})
