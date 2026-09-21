function Get-StartupPhaseFailureV35 {
 param([bool]$ListStarted,[bool]$ListReported,[bool]$BatchStarted,[bool]$BatchReported,[double]$CoreSeconds,[double]$ListSeconds)
 if($CoreSeconds -lt 0 -or $ListSeconds -lt 0){throw 'Invalid phase clock'}
 if($BatchStarted -or $BatchReported){return $null}
 if(!$ListStarted -and $CoreSeconds -gt 240){return 'Core/JVM startup deadline reached'}
 if($ListStarted -and !$ListReported -and $ListSeconds -gt 120){return 'Mike registration deadline reached'}
 return $null
}
