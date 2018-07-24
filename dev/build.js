if (process.argv.length != 3){
        if (process.argv.length == 4 && process.argv[3] == '--no-copyright'){
        }
        else {
            displayHelp();
            process.exit(1);
        }
}

console.log('Building MySQL SP Audit Script ...');


var data, file, result = '\
\n\
-- -------------------------------------------------------------------- \n\
-- MySQL Audit Trigger \n\
-- Copyright (c) 2014 Du T. Dang. MIT License \n\
-- https://github.com/hotmit/mysql-sp-audit \n\
-- Version: v' + process.argv[2] + '\n\
-- Build Date: ' + new Date().toUTCString() + '\n\
-- --------------------------------------------------------------------', 
    fileList = ['tbl_audit.sql', 'sp_generate_audit.sql', 'sp_generate_batch_audit.sql',
                'sp_generate_remove_audit.sql', 'sp_generate_batch_remove_audit.sql'],
    noCopyright = process.argv.length == 4 && process.argv[3] == '--no-copyright';


for (var i=0; i<fileList.length; i++){	
    file = fileList[i];
    data = readFile(__dirname + '/' + file);
    if (!data)
    {
        console.log('Error: cannot read file ' + file);
        process.exit(1);
    }
    if (noCopyright) {
        data = removeCopyright(data);
    }
    result += ('\n\n' + data);
}

writeFile(__dirname + '/../mysql_sp_audit_setup.sql', result);


function displayHelp(){
    console.log('');
    console.log('USAGE: node build.js <release_version> [<--no-copyright>]');
    console.log('    eg. node build.js 1.0');
    console.log('    eg. node build.js 1.7 --no-copyright');
    console.log('    <release_version> do not need to postfix with the little "v"');
    console.log('    --no-copyright remove the copyright notice from the script (if you want to)');
}

function removeCopyright(result)
{
    result = result.replace(new RegExp('-- Copyright \\(c\\) 2014 Du T. Dang. MIT License\\s*(\\\\n)*', 'gm'), '');
    result = result.replace(new RegExp('-- https://github.com/hotmit/mysql-sp-audit\\s*(\\\\n)*', 'gm'), '');

    return result;
}


function readFile(file){
    var fs = require('fs');
    return trim(fs.readFileSync(file).toString());
}

function writeFile(file, data){
    var fs = require('fs');
    fs.writeFile(file, data, function(err){
        if (err){
            console.log('Error: ' + err);
        }
    });
}

function trim (str) {
    return str.replace(/^[\s\xA0]+|[\s\xA0]+$/g, '');
}