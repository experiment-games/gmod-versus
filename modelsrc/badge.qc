$modelname "versus\badge\badge.mdl"

$staticprop

$bodygroup "Badge"
{
	studio "badge.smd"
}

$surfaceprop "popcan"

$contents "solid"

$illumposition 0 0.11 -0.035

$cdmaterials "versus/models/badge/"
$cdmaterials "versus/models/badge/faces/"

$texturegroup "skinfamilies"
{
	{ "front" }
	{ "gmod" }
	{ "versus" }
	{ "versus_og" }
}

$cbox 0 0 0 0 0 0

$bbox -0.582 -1.105 -1.079 0.522 1.197 1.161

$definebone "static_prop" "" 0 0 0 0 0 0 0 0 0 0 0 0

$sequence "idle" {
	"badge\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "badge.smd"
{
	$mass 0.020621
	$inertia 1
	$damping 0
	$rotdamping 0
	$rootbone " "
	$concave
	$maxconvexpieces 1
}
