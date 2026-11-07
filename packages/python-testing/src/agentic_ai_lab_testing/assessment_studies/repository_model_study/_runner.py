# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Runner for the repository model study study."""


def observed_runner(command):
    """Emit actual dependency import progress during cold interpreter startup."""
    return (
        """import sys,runpy,importlib.machinery
class ObservedLoader:
 def __init__(self,name,loader):self.name,self.loader=name,loader
 def __getattr__(self,name):return getattr(self.loader,name)
 def create_module(self,spec):
  print('DEPENDENCY-IMPORT-CREATE',self.name,flush=True)
  return self.loader.create_module(spec)
 def exec_module(self,module):
  print('DEPENDENCY-IMPORT-START',self.name,flush=True)
  self.loader.exec_module(module)
  print('DEPENDENCY-IMPORT-DONE',self.name,flush=True)
class ObservedFinder:
 def find_spec(self,name,path=None,target=None):
  if name.split('.')[0] not in ('sympy','networkx','pytest','scipy','numpy') or name.count('.')>5:return None
  spec=importlib.machinery.PathFinder.find_spec(name,path,target)
  if spec and isinstance(spec.loader,(importlib.machinery.SourceFileLoader,importlib.machinery.ExtensionFileLoader)):spec.loader=ObservedLoader(name,spec.loader)
  return spec
sys.meta_path.insert(0,ObservedFinder())
print('EXECUTION-START',flush=True)
args="""
        + repr(command)
        + """
if args[0]=='pytest':
 import pytest
 sys.exit(pytest.main(args[1:]))
else:runpy.run_path(args[0],run_name='__main__')
"""
    )
