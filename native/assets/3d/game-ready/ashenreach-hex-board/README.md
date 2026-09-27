# Ashenreach Runtime Board

The active Ashenreach terrain asset is:

`ashenreach_hex_board.glb`

This is the optimized runtime board used by `AshenreachDemo.tscn`.

Movement is now driven by the terrain-projected hex system in
`native/scripts/ashenreach_demo.gd`. The previous road-node map, standalone gate,
bedrock underlay, and old Ashenreach terrain assets have been retired.

Keep source-quality or experimental board exports outside this runtime folder unless
they are intentionally being promoted into the game.
