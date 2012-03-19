/**
 * Base class for all JBrowse data stores.
 * @class
 */

function Store( args ) {
};

Store.prototype.loadSuccess = function( data, url ) {
    this.data = data;
    this.empty = false;
    this.onReady();
};

Store.prototype.loadFail = function(error) {
    this.empty = true;
    this.error = true;
};

Store.prototype.load = function(url) {
    var that = this;
    dojo.xhrGet({ url: url || this.url,
                  handleAs: "json",
                  load: function(o)  { that.loadSuccess(o, url); },
                  error: function(o) { that.loadFail(o, url); }
	        });
};

Store.prototype.onReady = function() {
    this.ready = true;
    dojo.forEach( this.whenready || [], function( cbrec ) {
        cbrec[1].call( cbrec[0] );
    });
    this.changed();
};

/**
 * Schedule a callback to be called when the store is ready.
 */
Store.prototype.whenReady = function( context, callback ) {
    if( this.ready )
        callback.call( context );
    else {
        if( ! this.whenready ) this.whenready = [];
        this.whenready.push([context,callback]);
    }
};

Store.prototype.hideAll = function() {
};


Store.prototype.changed = function() {
};
