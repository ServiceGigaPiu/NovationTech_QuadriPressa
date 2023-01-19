#script version 1.0.0
#install app version 1.0.1
param ([switch]$appOnly)
write-host "`n  ## NODERED APP INSTALLER ## `n"

### CONFIGURATION
#installer
$ErrorActionPreference = "Inquire"
Set-location $PSScriptRoot

# nodejs
$node_version = "14.19.3"      #per modificare cerca da questo url la ver e dist prescelta: https://nodejs.org/dist/
$node_dist = "node-v$node_version-x64"
#$node_url = "https://nodejs.org/dist/$node_version/node-v$version.msi"
$node_url = "https://nodejs.org/dist/v$node_version/$node_dist.msi"

# git
$git_version = "2.39.0" #per modificare (non alla ceca) devi essere loggato su github e andare su https://github.com/git-for-windows/git/releases (repo ufficiale)
$git_url = "https://github.com/git-for-windows/git/releases/download/v$git_version.windows.1/Git-$git_version-64-bit.exe"

# node-red
$nodered_version = "3.0.2"

# app
$app_projDirName = "QuadripressaNovationTech" #expects a zip  ./name.zip to exctract
$app_projZip = "$app_projDirName.zip"
$app_toMove =   ("app_manualBkp2023.01.05_postProd(v1.0.1)","app"), #pair[ "path_RelativeTo_projDir","path_RelativeTo_noderedDir"] # , deve stare a fine riga #@() multilinea non va
                ("settings.js_manualBkp2023.01.04_postLogo(f74ca5a+)","settings.js")
                
                #,@ storico vers cliente/v1/package-lock
$app_useCheckoutSelect =$FALSE
#$app_keepProject defined below
$app_install_npmPackages = $TRUE


# extras
$gitExtension_version = "4.0.1" #per cambiare versione cambia l'url qua sotto, cercando su https://github.com/gitextensions/gitextensions/releases/
$gitExtension_url = "https://github.com/gitextensions/gitextensions/releases/download/v4.0.1/GitExtensions-4.0.1.15887-f2567dea2.msi"


# activate / deactivate any install

$install_node = $TRUE
$install_git = $TRUE
$install_nodered = $TRUE
$install_app = $TRUE
$install_gitExtension = $TRUE

function confirm {
    param (
        [Parameter(mandatory,position=0)]
        [Alias("m","message")]
        [string]$msg,
        
        [Parameter(position=1)]
        [Alias("d","def")]
        [string]$default='',

        [Parameter(position=2)]
        [Alias("o","opt","opts")]
        [string[]]$options = @('s','n')
    )
    write-host "$msg [" -NoNewline
    for (($i = 0); $i -lt $options.length; $i++) {
        if($i -ine 0) {
            write-host '/' -noNewLine
        }
        if($default -match $options[$i]){
            write-host $options[$i] -ForegroundColor DarkBlue -BackgroundColor yellow -NoNewline } else { write-host $options[$i] -NoNewline
        }
    }
    write-host "]: " -NoNewline
    return read-host
}


### INSTALLATION
$allGood = $FALSE
try {
    #header message
    $msg ="`nverranno installati:"
    if($install_node) {$msg = $msg+"`n - nodejs $node_version" }
    if($install_git) {$msg = $msg+"`n - git $git_version" }
    if($install_nodered) {$msg = $msg+"`n - node-red $nodered_version" }
    if($install_app) {$msg = $msg+"`n - l'applicazione contenuta in $app_projZip" }
    $msg = $msg+"`nfacoltativi:"
    if($install_gitExtension) {$msg = $msg+"`n - gitExtensionView $gitextension_version" }
    write-host $msg
    pause

    write-host "`n`n------------------------------" 
    write-host "controllo requisiti di sistema " -ForegroundColor blue -BackgroundColor white
    write-host "------------------------------`n" 

    ### require administator rights

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
       write-Warning "questo setup necessita dei permessi di amministratore. Per favore esegui questo file come amministratore."
       break
    }

    ###[node] detect already installed -> prompt: wait uninstall/skip
    if ($install_node) {
        if (Get-Command node -errorAction SilentlyContinue) {
            $node_current_version = (node --version)
        }

        if ($node_current_version) {
            $answ = confirm -m "[node] $node_current_version rilevata.`nla versione consigliata è $node_version. mantenere quella corrente?" -def "n"
            if($answ -ieq 's'){
                $install_node = $FALSE
            }
            else{
                write-Warning "disinstalla la versione corrente ed esegui nuovamente questo script."
                break
            }
        }
	    write-host "`n"
    }

    ###[git] detect git already installed -> prompt: wait uninstall/skip
    if ($install_git) {
        if (Get-Command git -errorAction SilentlyContinue) {
            $git_current_version = (git --version)
        }

        if ($git_current_version) {
            $answ = confirm -m "[GIT] $git_current_version rilevata.`nla versione consigliata è $git_version. mantenere quella corrente?" -def "n"
            if($answ -ieq 's'){
                $install_git = $FALSE
            }
            else{
                write-Warning "disinstalla la versione corrente ed esegui nuovamente questo script."
                break
            }
        }
	    write-host "`n"
    }



    ###[node-red] detect node-red already installed -> prompt: uninstall/keep
    if ($install_nodered) {
        if ((Get-Command node-red -errorAction SilentlyContinue) -and (Get-command npm -ErrorAction SilentlyContinue)) {
            (npm list -g node-red | out-string) -match "(?<v>[0-9\.]+)"
            $nodered_current_version = $Matches.v
        }

        if ($nodered_current_version) {
            $answ = confirm -m "[node-red] v$nodered_current_version rilevata.`nla versione consigliata è $nodered_version. mantenere quella corrente?" -def "n"
            if($answ -ieq 's'){
                $install_nodered = $FALSE
            }
            else{
                write-host "disinstallazione in corso.."
                npm uninstall -g node-red -wait
            }
        }
	    write-host "`n"
    }

    ###[app] detect app already installed
    if ($install_app) {
            #se .node-red esiste già
        if (Test-Path "$env:USERPROFILE\.node-red\") {
            Write-Warning "$env:USERPROFILE\.node-red\ esiste già"
            if (Test-Path "$env:USERPROFILE\.node-red\projects\$app_projDirName") { Write-Warning "il progetto $app_projDirName esiste già" }
            
            $options =  "`n (1) elimina l'intera cartella .node-red ed esegui un installazione pulita`n (2) installa l'applicazione da $((Get-Item $app_projZip).Directory.Name)"
            if(Test-Path "$env:USERPROFILE\.node-red\projects\$app_projDirName"){
                $options += "`n (3) installa l'applicazione dal progetto preesistente in .node-red/projects/" }
            
            do{
                $answ = read-host "scegli un opzione e digita il num corrispondente:$options`n"
                switch($answ){
                    '1' {$do = 'cleanInstall'}
                    '2' {$do = 'installFromZip'}
                    '3' {$do = 'installFromProj'}
                    default {$answ = $FALSE}
                }
            }while(-not $answ)

                #delete whole .node-red
            if($do -ieq 'cleanInstall'){
                write-host "..elimino ~\.node-red"
                remove-item -path "$env:USERPROFILE\.node-red" -Recurse
                if(Get-Command node-red -errorAction SilentlyContinue){
                   $answ = confirm -m "vuoi anche disinstallare e reinstallare node-red? " -def "n"
                   if($answ -ieq "s"){
			           npm uninstall -g node-red -wait
			           $install_nodered = $TRUE
                   }
			    }
            }
                #delete only same proj
            elseif($do -ieq 'installFromZip'){
                if(Test-Path "$env:USERPROFILE\.node-red\projects\$app_projDirName"){
                    Remove-Item "$env:USERPROFILE\.node-red\projects\$app_projDirName" -Recurse
                }
            }
                #just move files and install packages
            if(Test-Path "$env:USERPROFILE\.node-red\projects\$app_projDirName"){
                $app_keepProject = true
            }
        }
                

         <#
                remove-item -path "$env:USERPROFILE\.node-red\projects" -Recurse
                write-host "sembra che l'applicazione sia già stata installata in passato.`n..eliminata cartella progetto preesistente"
		    }else{
			    write-host "sembra che .node-red fosse già stato usato da questo utente."
		    }
                #?cancella /.node-red
		    write-host "Non è necessariamente un problema, ma questo caso non è stato testato.`nsi consiglia di cancellare l'intera cartella .node-red ed eseguire un'installazione pulita,`n perdendo tutti i dati utente E GLI ALTRI PROGETTI INSTALLATI"
		    $answ = confirm -m "vuoi cancellare /.node-red? " -def "n"
		    if($answ -ieq 's'){
                remove-item -path "$env:USERPROFILE\.node-red" -Recurse
			    if(Get-Command node-red -errorAction SilentlyContinue){
                   $answ = confirm -m "vuoi anche disinstallare e reinstallare node-red? " -def "n"
                   if($answ -ieq "s"){
			           npm uninstall -g node-red -wait
			           $install_nodered = $TRUE
                   }
			    }
		    }
            elseif(Test-Path "$env:USERPROFILE\.node-red\"){
                $answ = confirm -m "vuoi cancellare almeno la cartella progetto? verrà sovrascritta comunque " -def "n"
		        if($answ -ieq 's'){
            }
        }
        #>

	    write-host "`n"
    }

    ### INSTALLAZIONI

    write-host "`n`n-------------------------------" 
    write-host "   installazione  componenti   " -ForegroundColor blue -BackgroundColor white
    write-host "-------------------------------`n" 

    ### nodejs install
        #detect/download installer
    if ($install_node){
        $node_msi = "$PSScriptRoot\$node_dist.msi"
        write-host "`n -- INSTALLAZIONE DI NODE -- " -ForegroundColor blue -BackgroundColor white
        $download_node = $TRUE
            #detect prompt: (use it/download again)
        if (Test-Path $node_msi) {
            $node_msi -match "\\(?<fname>[^\\]+)$"
            $confirmation = confirm -m "rilevato installer per node in in $node_msi`n Saltare download e utilizzarlo? " -def "s"
            if (-not ($confirmation -ieq "n")) { #version is part of name so default answ is 'use it'
                $download_node = $FALSE
            }
        }
            #download
        if ($download_node) {
            write-host "scaricando l'installer di node per windows.."
        
            $start_time = Get-Date
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($node_url, $node_msi)
            write-Output "scaricato."
            write-Output "Tempo impiegato: $((Get-Date).Subtract($start_time).Seconds) secondi"
        }
            #print howTo
        write-host "eseguo $node_msi"
        write-host "----------[GUIDA]------------" -ForegroundColor blue -BackgroundColor white
	    write-host "modificare:"
        write-host "`n-[Tools for native modules] spunta 'automatically install the necessary tools.. IMPORTANTE"
        start-sleep -s 1 #allow to see that there is a guide
            #run installer
        start-Process $node_msi -wait -ErrorAction Inquire
		    #l'installer lancia altri installer, che prendono moooolto tempo
        while ($answ -ine 'completato'){
            $answ = read-host "attendi il completamento dell'installazione di tutti i sub-componenti, poi digita 'completato'.['completato'/ctrl-c] (il riavvio non è ancora necessario)"
	    }
            #reload env path to use it immediatly
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }


    ### git install
        #detect/download installer
    if ($install_git){
        $git_exe = "$PSScriptRoot\git-$git_version-installer.exe"
        write-host "`n -- INSTALLAZIONE DI GIT -- " -ForegroundColor blue -BackgroundColor white
        $download_git = $TRUE
            #detect prompt: (use it/download again)
        if (Test-Path $git_exe) {
            $confirmation = confirm -m "rilevato installer per git in $git_exe`n Saltare download e utilizzarlo? " -def "n"
            if ($confirmation -ieq "s") {
                $download_git = $FALSE
            }
        }
            #download
        if ($download_git) {
            write-host "scaricando l'installer di git per windows.."
        
            $start_time = Get-Date
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($git_url, $git_exe)
            write-Output "scaricato."
            write-Output "Tempo impiegato: $((Get-Date).Subtract($start_time).Seconds) secondi"
        }
            #print howTo
        write-host "eseguo $git_exe"
        write-host "----------[GUIDA]------------" -ForegroundColor blue -BackgroundColor white
	    write-host "modificare:`n-[choose git default editor] 'use vim ..' -> 'use Notepadd++ ..' (non indispensabile, se assente o in caso di errore lasciare invariato)"
        write-host "`n-[initial branch name] 'let git decide' -> 'override the default branch name..' con testo 'main' "
        write-host "`n-[configuring extra options] spunta 'Enable symbolic links'"
        start-sleep -s 1 #allow to see that there is a guide
            #run installer
	    if($app_useCheckoutSelect -and $install_app){
		    start-Process $git_exe -wait -ErrorAction Inquire } else { start-Process $git_exe -ErrorAction Inquire
	    }
    }




    ### npm packages install

    if($install_nodered){
	    write-host "`n -- INSTALLAZIONE DI NODERED -- " -ForegroundColor blue -BackgroundColor white
            #install/error
		if(get-command npm -errorAction silentlyContinue){
			npm install -g --unsafe-perm node-red
			write-host "`nnode-red installato`n"
		}
		else{
			write-error "npm non disponibile, installa Node.js o riavvia il pc"
		}
	
        
    }

    ### app install

    write-host "`n-----------------------------" 
    write-host " INSTALLAZIONE APPLICAZIONE  " -ForegroundColor blue -BackgroundColor white
    write-host "-----------------------------`n" 
        #sovrascrivi tutto se esiste già
    if($install_app){        
        $nodered_dir = $env:userprofile+"\.node-red"
        #$nodered_proj_dir = "$nodered_dir\projects\"
        #crea ed estraici cartella progetto
	    if(-not (test-path $nodered_dir)) { New-Item -path $nodered_dir -type Directory | out-null}
	    if(-not (test-path "$nodered_dir\projects")) { New-Item -path "$nodered_dir\projects" -type Directory | out-null}
        write-host "`nestrazione progetto $app_projDirName da $app_projZip.."
        Expand-Archive -Path $app_projZip -DestinationPath "$nodered_dir\projects\$app_projDirName" -Force -errorAction Inquire
    
	    #copia app_base,settings_base.js
        write-host "`ncopia file e cartelle standard.."
        foreach ($pair in $app_toMove){ 
            write-host (".." + $pair[0])
            Copy-Item -path ("$nodered_dir\projects\$app_projDirName\" + $pair[0]) -Destination ("$nodered_dir\" + $pair[1]) -Recurse -Force
        }

        #Copy-Item -path "$nodered_dir\projects\$app_projDirName\flows.json" -Destination "$nodered_dir\flows.json" -Force
        Copy-Item -path "$nodered_dir\projects\$app_projDirName\flows_cred.json" -Destination "$nodered_dir\flows_cred.json" -Force
        
        if($app_install_npmPackages){
	        write-host "`ninstallazione moduli.."
            if(test-path "$nodered_dir\package-lock"){ remove-item "$nodered_dir\package-lock"} #takes precedence over package.json
	        Copy-Item -path "$nodered_dir\projects\$app_projDirName\package.json" -Destination "$nodered_dir\package.json" -Force
            set-location $nodered_dir
            npm prune
            npm install
        }

        if($install_git){
           $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
        }
        if(get-command git -ErrorAction SilentlyContinue){
            git config --global --add safe.directory "$nodered_dir\projects\$app_projDirName"
            write-host "..aggiunta eccezione cartella progetto, in caso non si conoscano le credenziali"
        }

        <#
        Copy-Item -path "$nodered_dir\projects\$app_projDirName\app_base" -Destination "$nodered_dir\app" -Recurse
        Copy-Item -path "$nodered_dir\projects\$app_projDirName\settings.js" -Destination "$nodered_dir\app"
        #>
        write-host "applicazione installata."
            #? usa progetto / copia flows in .node-red
        if(-not (get-command git -ErrorAction SilentlyContinue)){
            write-warning "git command not found, i progetti potrebbero non funzionare."
            #$answ = confirm -m "   piano b: rallenterà sostanzialmente l'avvio. copiare flows.json in .node-red? " -def "s"
        }
        write-host "`noperazione manuale necessaria: configurazione progetto."
        $answ=confirm -m "vuoi effettuarla adesso? " -def "s"
        if($answ -ieq "n"){
            write-host "..copy flows to .node-red"
            Copy-Item -path "$nodered_dir\projects\$app_projDirName\flows.json" -Destination "$nodered_dir\flows.json" -Force
        }
        else {
            write-host "..lancio node-red in background (chiudere lo script chiuderà anche il server)"
            $nrProc = start-process node-red -WindowStyle normal -PassThru
            start-sleep -Seconds 3

            #while(-not $answ -or -not ($answ -match "q")){
                #$answ = confirm -m "wa" -def "quit" -opt "repeat","quit"
                start-process "http://127.0.0.1:1880/#flow/" -WindowStyle normal
            #}

            write-host " --[GUIDA]-- " -ForegroundColor blue -BackgroundColor white
            write-host "il server di node red potrebbe impiegare qualche secondo ad avviarsi: `n  ricarica la pagina all'occorrenza."
            write-host "- salta il tutorial introduttivo (x)"
            write-host "- si aprirà immediatamente un altro pop-up che chiede di creare/clonare un progetto:"
            write-host "     scegli 'apri progetto esistente', piccolo e poco visibile in basso"
            write-host "- se conosci le credenziali della repository (gitLab o simili) inseriscile,"
            write-host "     altrimenti inserisci qualsiasi carattere e prosegui"
            write-host " -- ho chiuso il popup, come lo riapro? --" -ForegroundColor yellow -BackgroundColor blue
            write-host "- dal menu in alto a desta (tre linee) scegli: projects -> open"
            write-host "- nella sotto-finestra che si apre seleziona $app_projDirName, poi 'open project'"
            write-host " -- non si è aperto nulla e non c'è nessuna voce 'projects' nel menu! --" -ForegroundColor yellow -BackgroundColor blue
            write-host "con tutta probabilità GIT non risulta installato, puoi provare a:"
            write-host "- prova a chiuderela console di node-red e riaprirla (tasto windows+R -> scrivi node-red -> invio)"
            write-host "- prova a riavviare il PC o reinstallare GIT"
            write-host "- salta la configurazione, non è indispensabile"
            pause
           
            write-host "..copy flows to .node-red"
            Copy-Item -path "$nodered_dir\projects\$app_projDirName\flows.json" -Destination "$nodered_dir\flows.json" -Force
           


            if($nrProc){
                stop-process -InputObject $nrProc -ErrorAction SilentlyContinue } #non funziona..
            Stop-Process -Name "node" -ErrorAction SilentlyContinue

            write-host "configurazione completata"
        }
    }
    


    ### extras

    write-host "`n----------------------------" 
    write-host "         extra tools        " -ForegroundColor blue -BackgroundColor white
    write-host "----------------------------`n" 


    if ($install_gitExtension){
        $answ = confirm -m "[gitExtensionView] Rende più rapido risolvere problemi da remoto e mantenere le versioni in azienda aggiornate con quella nella macchina del cliente.`n vuoi installare git Extensions?`n  " -def "s"
        if($answ -ine "n"){
            $gitExtension_msi = "$PSScriptRoot\gitExtension-$gitExtension_version-installer.msi"
            write-host "`n -- INSTALLAZIONE DI gitExtension -- "
            $download_gitExtension = $TRUE
                #detect prompt: (use it/download again)
            if (Test-Path $gitExtension_msi) {
                $gitExtension_msi -match "\\(?<fname>[^\\]+)$"
                $confirmation = confirm -m "rilevato installer per gitExtension in $gitExtension_msi`n Saltare download e utilizzarlo? " -def "n"
                if ($confirmation -ieq "s") {
                    $download_gitExtension = $FALSE
                }
            }
                #download
            if ($download_gitExtension) {
                write-host "scaricando l'installer di gitExtension per windows.."
        
                $start_time = Get-Date
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($gitExtension_url, $gitExtension_msi)
                write-Output "scaricato."
                write-Output "Tempo impiegato: $((Get-Date).Subtract($start_time).Seconds) secondi"
            }
            write-host "eseguo $gitExtension_msi"
                #run installer
            start-Process $gitExtension_msi -ErrorAction Inquire -wait
        }
    }
    $allGood = $TRUE
}

### clean
finally {
	if(-not $allGood){
		write-error "installazione non completata" }
    Set-Location $PSScriptRoot #in case one wants to restart this script
    write-host "`n----------------------------" 
    write-host "   pulizia " -ForegroundColor blue -BackgroundColor white
    write-host "----------------------------`n" 

    $confirmation = $TRUE #confirm -m "elimina installer scaricati? " -def "s"
    if ($confirmation -ine "n") {
        if ($node_msi -and (Test-Path $node_msi)) {
            rm $node_msi
			write-host "..rem $node_msi"
        }
        if ($git_exe -and (Test-Path $git_exe)) {
            rm $git_exe
			write-host "..rem $git_exe"
        }
        if ($gitExtension_msi -and (Test-Path $gitExtension_msi)) {
            rm $gitExtension_msi
			write-host "..rem $gitExtension_msi"
        }
    }
}


write-host "fatto !"

# If running in the console, wait for input before closing.
if ($Host.Name -eq "ConsoleHost")
{
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
}