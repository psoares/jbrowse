var SeqFeatureStore; if( !SeqFeatureStore) SeqFeatureStore = function() {};

/**
 * Implementation of SeqFeatureStore using nested containment
 * lists held in static files that are lazily fetched from the web
 * server.
 *
 * @class
 * @extends SeqFeatureStore
 */

SeqFeatureStore.NCList = function(args) {
    SeqFeatureStore.call( this, args );
    if( !args )
        return;

    this.nclist = this.makeNCList();

    this.baseUrl = args.baseUrl;
    this.urlTemplates = { tracklist: args.urlTemplate };
};

SeqFeatureStore.NCList.prototype = new SeqFeatureStore();

SeqFeatureStore.NCList.prototype.makeNCList = function() {
    return new NCList();
};

SeqFeatureStore.NCList.prototype.forRefSeq = function( refSeqName, callback ) {
    if( !(refSeqName in this.nclists )) {
        var that = this,
        data_root_url = Util.resolveUrl(
            this.baseUrl,
            Util.fillTemplate( this.urlTemplates.tracklist,
                               {'refseq': refSeqName }
                             )
        );

        this.nclists[refSeqName] = 'loading';
        // fetch the trackdata
        dojo.xhrGet({ url: url,
                      handleAs: "json",
                      load:  Util.debugHandler( this, function(o) { that.loadSuccess(o, url); }),
                      error: function(e) { console.error(''+e); that.loadFail(e, url);    }
	            });
    } else {

    }
};

SeqFeatureStore.NCList.prototype.loadSuccess = function( trackInfo, url ) {

    this.count = trackInfo.featureCount;
    // average feature density per base
    this.density = trackInfo.featureCount / this.refSeq.length;

    this.loadNCList( trackInfo, url );

    if (trackInfo.histograms) {
        this.histograms = trackInfo.histograms;
        for (var i = 0; i < this.histograms.meta.length; i++) {
            this.histograms.meta[i].lazyArray =
                new LazyArray(this.histograms.meta[i].arrayParams, url);
        }
    }
};

SeqFeatureStore.NCList.prototype.loadNCList = function( trackInfo, url ) {
    this.attrs = new ArrayRepr(trackInfo.intervals.classes);
    this.nclist.importExisting( trackInfo.intervals.nclist,
                                this.attrs,
                                url,
                                trackInfo.intervals.urlTemplate,
                                trackInfo.intervals.lazyClass
                              );
};


SeqFeatureStore.NCList.prototype.loadFail = function(trackInfo,url) {
};

// just forward histogram() and iterate() to our encapsulate nclist
SeqFeatureStore.NCList.prototype.iterateHistogram = function() {
    return this.nclist.histogram.apply( this.nclist, arguments );
};


SeqFeatureStore.NCList.prototype.iterate = function( args ) {
    var that = this;
    var accessors    = this.attrs.accessors(),
        /** @inner */
        featCallback = function( feature, path ) {
            that._add_getters( accessors.get, feature );
            return args.featureCallback( feature, path );
        };

    return this.nclist.iterate.call( this.nclist, args.start, args.end, featCallback, args.finishCallback );
};

/**
 * Helper method to recursively add a .get method to a feature and its subfeatures.
 * @private
 */
SeqFeatureStore.NCList.prototype._add_getters = function(getter,feature) {
    var that = this;
    feature.get = getter;
    dojo.forEach( feature.get('subfeatures'), function(f) { that._add_getters( getter, f ); } );
};

