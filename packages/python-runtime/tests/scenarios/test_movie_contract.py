import unittest,json,copy
from ascent import Engine,rows_equal
class MovieContract(unittest.TestCase):
    def setUp(self):
        self.engine=Engine()
        self.addCleanup(self.engine.close)
    def test_movie_contract_shape_repair_and_current_source_witnesses(self):
            from agentic_ai_lab_testing.assessment_studies import complex_movie_study as study
            from agentic_ai_lab_testing.assessment_studies.complex_movie_validation import singleton_heads
            source=json.loads(study.FIXTURE.read_text());case=study.cases()[0]
            views=study.materialize(self.engine,source)
            valid=study.gold(case,True);malformed=copy.deepcopy(valid)
            malformed['rules'][0]['head']=malformed['rules'][0]['head'][0]
            with self.assertRaises((TypeError,ValueError)):
                study.program(source,malformed,views)
            repaired,count=singleton_heads(malformed)
            self.assertEqual(count,1);self.assertEqual(repaired,valid)
            actual=study.case_program(self.engine,source,case,repaired,views)
            self.assertTrue(rows_equal(actual, [['Q123351'],['Q208026'],['Q202589']]))
            changed={**case,'withdrawal':['Q25188','Q123351']};current=study.source_for(source,changed)
            fresh_views=study.materialize(self.engine,current)
            correct=study.case_program(self.engine,current,changed,repaired,fresh_views)
            stale=study.case_program(self.engine,current,changed,repaired,views)
            self.assertTrue(rows_equal(correct, [['Q208026'],['Q202589']]))
            self.assertFalse(rows_equal(stale, correct))
            union={**case,'combine':'any','scope':'both'}
            mistaken={**union,'combine':'all'}
            union_answer=study.case_program(self.engine,source,union,study.gold(union,True),views)
            join_answer=study.case_program(self.engine,source,union,study.gold(mistaken,True),views)
            self.assertEqual(len(union_answer),154);self.assertEqual(len(join_answer),3)
            self.assertFalse(rows_equal(union_answer, join_answer))
            scoped,qualified,withdrawal=study.cases('country-qualified')
            single=study.case_program(self.engine,source,qualified,study.gold(qualified,True),views)
            self.assertEqual(single,[['Q208026']])
            selective=study.case_program(self.engine,source,scoped,study.gold(scoped,True),views)
            self.assertEqual(len(selective),89);self.assertIn(['Q208026'],selective)
            current=study.source_for(source,withdrawal);updated_views=study.materialize(self.engine,current)
            changed=study.case_program(self.engine,current,withdrawal,study.gold(withdrawal,True),updated_views)
            self.assertEqual(len(changed),88);self.assertNotIn(['Q208026'],changed)
            # Fusing the two branch film variables in the direct answer rule loses Hardy.
            a,f,d,e=map(study.var,('a','f','d','e'))
            fused={'relations':[],'rules':[study.rule(study.atom('answer',a),
                study.atom('eligible',study.const('Q145'),f,d,a),
                study.atom('omitted_film',f,negative=True),
                study.atom('eligible',study.const('Q96'),f,e,a),
                study.atom('coactor',study.const('Q38111'),f,a))]}
            self.assertEqual(study.case_program(self.engine,source,qualified,fused,views),[])
