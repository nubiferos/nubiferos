#!/usr/bin/env python3
"""
Token Generators for NubiferOS Credential Manager

Provides STS token generation for cloud providers.
"""

from .aws import AWSTokenGenerator, AWSTokenGeneratorError

__all__ = ['AWSTokenGenerator', 'AWSTokenGeneratorError']
