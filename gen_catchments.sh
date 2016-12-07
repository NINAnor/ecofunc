g.region -p raster=dem_10m_nosefi_float@PERMANENT n=n+30 e=e+30 res=50
g.remove -f type=vector name=ECOFUNC_watersheds@p_ECOFUNC_stefan.blumentrath
g.copy vector=Fenoscandia_ECRINS_AggregationCatchments_RBD_Int_Clp@g_Hydrography,ECOFUNC_watersheds
v.db.addcolumn --verbose map=ECOFUNC_watersheds@p_ECOFUNC_stefan.blumentrath columns="id integer"
db.execute sql="UPDATE ECOFUNC_watersheds SET id = (SELECT n FROM (SELECT IRbdID, (SELECT count(*) FROM (SELECT DISTINCT IRbdID FROM ECOFUNC_watersheds) AS x WHERE x.IRbdID >= y.IRbdID) AS n FROM ECOFUNC_watersheds AS y) AS a WHERE a.IRbdID = ECOFUNC_watersheds.IRbdID);"
v.to.rast --overwrite --verbose input=ECOFUNC_watersheds output=ECOFUNC_watersheds use=attr attribute_column=id label_column=Name_E memory=30000
r.resamp.stats --overwrite --verbose input=dem_10m_nosefi@PERMANENT output=dem_50m_nosefi
r.resamp.stats --overwrite --verbose input=Norge_Sverige_Finland_rel_forest_line@p_fjr_10m output=Norge_Sverige_Finland_rel_forest_line_50m

r.mapcalc --o expression="gen_altitude_areas=if(isnull(Norge_Sverige_Finland_rel_forest_line_50m), 1, if(Norge_Sverige_Finland_rel_forest_line_50m >= 100, 3, if(Norge_Sverige_Finland_rel_forest_line_50m < 100 && Norge_Sverige_Finland_rel_forest_line_50m >= 50, 2, 1)))"
r.to.vect --overwrite --verbose input=gen_altitude_areas output=gen_altitude_areas

r.resamp.stats --overwrite --verbose input=dem_50m_nosefi@p_ECOFUNC_stefan.blumentrath output=dem_100m_nosefi
