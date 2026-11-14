# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Exact Rust checks, atomic observations and immutable compiled checker identity."""
import unittest
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import DomainEvidence, domain_check, domain_checker_version


class DomainEvidenceIntegration(unittest.TestCase):
    def test_exact_domain_constraints_retention_and_invalidation(self):
        with ReasoningRuntime() as engine, DomainEvidence(engine,'source-A') as memory:
            bad=memory.observe('graph-schedule',[['g',[1,3,7,9],[1,3],[3,1]]],'trace-g')
            self.assertTrue(bad['failedClaims'])
            self.assertEqual(bad['currentChecks'][0]['requiredOrder'],[1,3])
            update=memory.observe('graph-update',[['u',2,1,5,2,3]],'trace-u')
            self.assertEqual(len(update['checkedDomainEvidence']),2)
            self.assertEqual(update['currentChecks'][0]['claims'],[['update-read-version',False],['path-count-conservation',True],['path-count-nonnegative',True]])
            series=memory.observe('series-precision',[
                ['reciprocal',[1,1],-1,[3,1],[2,1],[3,1],False],
                ['boundary',[4,1],2,[2,1],[0,1],[0,1],False]],'trace-series')
            self.assertEqual(series['currentChecks'][0]['requiredInternalPrecision'],[4,1])
            self.assertTrue(series['currentChecks'][0]['shouldInclude'])
            self.assertFalse(series['currentChecks'][1]['shouldInclude'])
            self.assertEqual(len(series['checkedDomainEvidence']),3)
            memory.summary()
            self.assertTrue(memory.journal[-1]['reusedComponents'])
            old=series['resultReference']
            memory.replace_snapshot('source-B')
            summary=memory.summary()
            self.assertEqual(summary['checkedDomainEvidence'],[])
            self.assertEqual(len(summary['domainContracts']),3)
            self.assertFalse(summary['failedClaims'])
            good=memory.observe('graph-schedule',[['g',[1,3,7,9],[1,3],[1,3]]],'trace-fixed')
            self.assertFalse(good['failedClaims'])
            self.assertEqual(len(good['checkedDomainEvidence']),1)
            with self.assertRaises(ValueError):memory.answer(old,'Failed')
            before=memory.summary()['checkedDomainEvidence']
            with self.assertRaises(ValueError):
                memory.observe('series-precision',[['bad',[1,0],2,[3,1],[2,1],[0,1],True]],'bad-denominator')
            self.assertEqual(memory.summary()['checkedDomainEvidence'],before)
            with self.assertRaises(ValueError):domain_check('series-precision',[['bad',[1,0],2,[3,1],[2,1],[0,1],True]])
            self.assertEqual(memory.checker_version,domain_checker_version())
            with self.assertRaises(AttributeError):memory.checker_version='forged-checker-version'
            self.assertFalse(hasattr(engine,'request'))
