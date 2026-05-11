
var folderUrl = "file:///C|/Users/PGaming/Desktop/BleachVsNaruto/BleachVsNaruto_FlashSrc";
var logFile = "file:///C|/Users/PGaming/Desktop/BleachVsNaruto/temp/jsfl_log.txt";

function log(msg) {
	FLfile.write(logFile, msg + "\n", "append");
}

function getFilesByDir(dirUrl) {
	var files = [];
	var flaFileList = FLfile.listFolder(dirUrl + "/*.fla", "files");
	for (var i = 0; i < (flaFileList ? flaFileList.length : 0); i++) {
		files.push(dirUrl + "/" + flaFileList[i]);
	}
	
	var dirList = FLfile.listFolder(dirUrl, "directories");
	for (var j = 0; j < (dirList ? dirList.length : 0); j++) {
		var curDir  = dirUrl + "/" + dirList[j];
		var xflFile = curDir + "/" + dirList[j] + ".xfl";
		
		if (!FLfile.exists(xflFile)) {
			files = files.concat(getFilesByDir(curDir));
			continue;
		}
		files.push(xflFile);
	}
	return files;
}

function main() {
	FLfile.write(logFile, "Starting Batch Publish...\n", "overwrite");
	if (!FLfile.exists(folderUrl)) {
		log("Folder not found: " + folderUrl);
		return;
	}
	
	var files = getFilesByDir(folderUrl);
	log("Found " + files.length + " files.");
	
	for (var i = 0; i < files.length; i++) {
		log("Opening: " + files[i]);
		var doc = fl.openDocument(files[i]);
		if (doc) {
			log("Publishing: " + files[i]);
			doc.publish();
			doc.close(false);
		} else {
			log("Failed to open: " + files[i]);
		}
	}
	log("Done.");
	fl.quit();
}

main();
