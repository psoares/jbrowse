var profile = {
    releaseDir: 'release/',
    basePath: '..',
    action: 'release',

    resourceTags: {
        amd: function(filename,mid) {
            return mid == 'jslib';
        },
        copyOnly: function(filename,mid) {
            return mid == 'js';
        }
    },
    layers: {
        "jslib/jbrowse_dojo": {
            include: ["dojo/dojo", "dojo/dnd", "dijit/layout" ]
        }
    }
};

// The old profile file
// dependencies = (
//     {
//         prefixes: [
//             ["dijit", "../dijit"]
//         ],
//         layers: [
//             {
//                 dependencies: [
//                     "dojo.dnd.Source",
//                     "dojo.dnd.Moveable",
//                     "dojo.dnd.Mover",
//                     "dojo.dnd.move",
//                     "dijit.layout.ContentPane",
//                     "dijit.layout.BorderContainer"
//                 ],
//                 layerDependencies: [],
//                 name: "jbrowse_dojo.js",
//                 resourceName: "jbrowse_dojo"
//             }
//         ]
//     }
// );
