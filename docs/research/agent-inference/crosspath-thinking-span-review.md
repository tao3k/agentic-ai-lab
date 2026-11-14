# Cross-goal thinking span review

This post-outcome qualitative audit preserves the frozen automatic annotations. It distinguishes explicit proof reconstruction from conjunction restatement and new alternative witnesses. It is not a blinded independent-rater validation.

Automatic matches: 10. Six reconstruct complete two-path support; one repeats one path explicitly; one only restates a conjunction; two repeat a prior proof core while adding an alternative witness.

## Paired original spans

### fresh F0

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1279, 1340]:

> - 0->7: 0->2->4->7 yes. 1->9: 1->2->4->7->9 yes. F0 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [431, 511]:

> F0: (0,7) and (1,9). 0->7: 0->2->4->7 yes. 1->9: 1->2->4->7->9 yes. F0 eligible.

### fresh F1

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1341, 1404]:

> - 2->9: 2->4->7->9 yes. 3->11: 3->6->8->9->11 yes. F1 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [512, 595]:

> F1: (2,9) and (3,11). 2->9: 2->4->7->9 yes. 3->11: 3->6->8->9->11 yes. F1 eligible.

### fresh F2

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1405, 1462]:

> - 4->11: 4->7->9->11 yes. 5->9: 5->7->9 yes. F2 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [596, 673]:

> F2: (4,11) and (5,9). 4->11: 4->7->9->11 yes. 5->9: 5->7->9 yes. F2 eligible.

### fresh F3

one explicit path-chain replay plus reuse/assertion of the other premise

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1463, 1511]:

> - 0->11: yes. 3->9: 3->6->8->9 yes. F3 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [674, 741]:

> F3: (0,11) and (3,9). 0->11 yes. 3->9: 3->6->8->9 yes. F3 eligible.

### fresh F4

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1512, 1572]:

> - 1->7: 1->2->4->7 yes. 6->11: 6->8->9->11 yes. F4 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [742, 822]:

> F4: (1,7) and (6,11). 1->7: 1->2->4->7 yes. 6->11: 6->8->9->11 yes. F4 eligible.

### fresh F5

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1573, 1627]:

> - 2->7: 2->4->7 yes. 8->11: 8->9->11 yes. F5 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [823, 897]:

> F5: (2,7) and (8,11). 2->7: 2->4->7 yes. 8->11: 8->9->11 yes. F5 eligible.

### fresh F7

conjunction-only restatement; no explicit path re-derivation demonstrated

Goal 0, SHA256 `88ff491db08da00dfab8b8918cf63c20cde0869c3853bbc83957d00c1beb13a9`, span [1674, 1712]:

> - 0->9: yes. 10->11: yes. F7 eligible.

Goal 1, SHA256 `246832a1f3524835d589ec22bf3c7e857d820376b7ebb7b37f749b53cf281850`, span [964, 1021]:

> F7: (0,9) and (10,11). 0->9 yes. 10->11 yes. F7 eligible.

### retained F4

previous proof core is printed again, with an additional alternative witness; automated full-premise identity is incomplete

Goal 0, SHA256 `3dfee3e66fdba0dcfd3607971b7a6f36f0aaac32c9af0b093c3614f79687c8c4`, span [3220, 3303]:

> Fragment 4: [4,1,7,6,11]: 1->7 yes (1->2->4->7), 6->11 yes (6->8->9->11). Eligible.

Goal 1, SHA256 `baf5fa8ef2412c976828dadab8e8c8bc3b51bd2cd34983d0be2d1624e9f4f728`, span [2120, 2210]:

> F4 need (4,1,7,6,11): 1->7 yes 1->2->4->7 or 1->2->5->7. 6->11? 6->8->9->11 yes. Eligible.

### retained F5

previous proof core is printed again, with an additional alternative witness; automated full-premise identity is incomplete

Goal 0, SHA256 `3dfee3e66fdba0dcfd3607971b7a6f36f0aaac32c9af0b093c3614f79687c8c4`, span [3304, 3381]:

> Fragment 5: [5,2,7,8,11]: 2->7 yes (2->4->7), 8->11 yes (8->9->11). Eligible.

Goal 1, SHA256 `baf5fa8ef2412c976828dadab8e8c8bc3b51bd2cd34983d0be2d1624e9f4f728`, span [2211, 2292]:

> F5 need (5,2,7,8,11): 2->7 yes 2->4->7 or 2->5->7. 8->11? 8->9->11 yes. Eligible.

### retained F6

same complete two-path support explicitly reconstructed (direct source edges also count as witnesses)

Goal 0, SHA256 `3dfee3e66fdba0dcfd3607971b7a6f36f0aaac32c9af0b093c3614f79687c8c4`, span [3382, 3448]:

> Fragment 6: [6,3,8,9,11]: 3->8 yes (3->6->8), 9->11 yes. Eligible.

Goal 1, SHA256 `baf5fa8ef2412c976828dadab8e8c8bc3b51bd2cd34983d0be2d1624e9f4f728`, span [2293, 2353]:

> F6 need (6,3,8,9,11): 3->8 yes 3->6->8. 9->11 yes. Eligible.

