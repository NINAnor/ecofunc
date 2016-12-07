#!/bin/bash
# Set analysis region
g.region -p raster=dem_10m_nosefi_float@PERMANENT n=n+80 e=e+80 res=100

# Remove old watersheds map (will fail if not present)
g.remove -f type=vector name=ECOFUNC_watersheds@p_ECOFUNC_stefan.blumentrath
# Copy WFD watersheds
g.copy vector=Fenoscandia_ECRINS_AggregationCatchments_RBD_Int_Clp@g_Hydrography,ECOFUNC_watersheds

# Add ID column and populate it with integer values
v.db.addcolumn --verbose map=ECOFUNC_watersheds@p_ECOFUNC_stefan.blumentrath columns="id integer"
db.execute sql="UPDATE ECOFUNC_watersheds SET id = (SELECT n FROM (SELECT IRbdID, (SELECT count(*) FROM (SELECT DISTINCT IRbdID FROM ECOFUNC_watersheds) AS x WHERE x.IRbdID >= y.IRbdID) AS n FROM ECOFUNC_watersheds AS y) AS a WHERE a.IRbdID = ECOFUNC_watersheds.IRbdID);"

# Convert watersheds to raster
v.to.rast --overwrite --verbose input=ECOFUNC_watersheds output=ECOFUNC_watersheds use=attr attribute_column=id label_column=Name_E memory=30000

# Resample terrain model to 100m resolution
r.resamp.stats --overwrite --verbose input=dem_10m_nosefi@PERMANENT output=dem_100m_nosefi

# Remove nodata values and pixels with 0 movement costs (set them to 1)
r.mapcalc --o expression="dem_100m_nosefi_non_neg=if(dem_100m_nosefi<=0,1,dem_100m_nosefi)"
#r.mapcalc --o expression="dem_100m_nosefi_non_neg=if(dem_100m_nosefi<0,0,dem_100m_nosefi)"

# Calculate cost distance (with altitude representing movement costs) from the southern tip of Sweden
r.cost --o input=dem_100m_nosefi_non_neg outdir=gen_catchment_cost_outdir output=gen_catchment_cost_dist start_coordinates="361156,6135594" memory=60000

# Get 33 and 66 percentiles of cost distance by watershed
r.stats.quantile --overwrite --verbose base=ECOFUNC_watersheds@p_ECOFUNC_stefan.blumentrath cover=gen_catchment_cost_dist@p_ECOFUNC_stefan.blumentrath percentiles=33,66 output=ECOFUNC_watersheds_perc33,ECOFUNC_watersheds_perc_66

# Subdevide watersheds by percentiles
r.mapcalc --o expression="ECOFUNC_gen_watersheds=if(isnull(gen_catchment_cost_dist) && ! isnull(ECOFUNC_watersheds), 1000, if(gen_catchment_cost_dist>ECOFUNC_watersheds_perc_66,3000,if(gen_catchment_cost_dist>ECOFUNC_watersheds_perc33,2000,1000)))+ECOFUNC_watersheds"

# Convert subdevided watersheds to vector
r.to.vect --o -s -v --overwrite --verbose input=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath output=ECOFUNC_gen_watersheds type=area

# Add columns for watershed ID (wid) and distance percentile (distid with 1: <33%, 2: 33 to <66%, 3 >= 66%)
v.db.addcolumn map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath columns="wid integer,distid integer"

# Fill wid column with values
v.db.update map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=wid value="cat - 1000" where="cat < 2000"
v.db.update map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=wid value="cat - 2000" where="cat < 3000 AND cat >= 2000"
v.db.update map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=wid value="cat - 3000" where="cat >= 3000"

# Fill distid column with values
v.db.update --quiet map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=distid value=1 where="cat < 2000"
v.db.update map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=distid value=2 where="cat < 3000 AND cat >= 2000"
v.db.update map=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath layer=1 column=distid value=3 where="cat >= 3000"

# Export result to shape
v.out.ogr -s -m --overwrite --verbose input=ECOFUNC_gen_watersheds@p_ECOFUNC_stefan.blumentrath type=area output=/home/stefan.blumentrath/ECOFUNC_gen_watersheds.shp format=ESRI_Shapefile
