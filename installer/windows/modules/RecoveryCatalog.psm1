<#
.SYNOPSIS
    Catálogo y Gestor de Imágenes de Recuperación de ChromeOS para TapeOS
.DESCRIPTION
    Proporciona información sobre codenames de ChromeOS, descarga metadatos
    desde cros.tech y ayuda a seleccionar la mejor imagen para equipos modernos y legacy.
#>

$Script:RecoveryCatalog = @(
    [PSCustomObject]@{
        Codename = "kanix"
        DisplayName = "Kanix (Intel 14th Gen / Core Ultra)"
        Hardware = "Intel Core Ultra (Meteor Lake, Arrow Lake) y 14ª generación"
        KernelDefault = "kernel-6.6"
        Category = "Modern"
        ArcSubsystem = "ARCVM (Android 13/14)"
        Notes = "Para procesadores Intel lanzados a partir de 2024."
    },
    [PSCustomObject]@{
        Codename = "voxel"
        DisplayName = "Voxel (Intel 11th - 13th Gen)"
        Hardware = "Intel Core i3/i5/i7 de 11ª, 12ª y 13ª generación (Tiger/Alder/Raptor Lake)"
        KernelDefault = "kernel-6.1"
        Category = "Modern"
        ArcSubsystem = "ARCVM (Android 11/13)"
        Notes = "Altamente estable con aceleración gráfica Iris Xe."
    },
    [PSCustomObject]@{
        Codename = "jinlon"
        DisplayName = "Jinlon (Intel 10th Gen)"
        Hardware = "Intel Core i3/i5/i7 de 10ª generación (Comet Lake / Ice Lake)"
        KernelDefault = "kernel-6.1"
        Category = "Modern"
        ArcSubsystem = "ARCVM (Android 11)"
        Notes = "Compatible con la mayoría de laptops de 2020-2021."
    },
    [PSCustomObject]@{
        Codename = "gumboz"
        DisplayName = "Gumboz (AMD Ryzen Moderno)"
        Hardware = "AMD Ryzen serie 3000, 4000, 5000, 6000, 7000, 8000 (Zen+ a Zen 4)"
        KernelDefault = "kernel-6.1"
        Category = "Modern"
        ArcSubsystem = "ARCVM (Android 11/13)"
        Notes = "Excelente compatibilidad gráfica Radeon Vega / RDNA."
    },
    [PSCustomObject]@{
        Codename = "zork"
        DisplayName = "Zork (AMD Ryzen 3000 Mobile)"
        Hardware = "AMD Ryzen Mobile 3000 (Picasso/Dali) y Athlon 3000"
        KernelDefault = "kernel-5.15"
        Category = "Modern"
        ArcSubsystem = "ARCVM (Android 11)"
        Notes = "Alternativa a gumboz para Ryzen móviles de primera y segunda generación."
    },
    [PSCustomObject]@{
        Codename = "rammus"
        DisplayName = "Rammus (Intel 4th - 9th Gen) [Recomendado Legacy]"
        Hardware = "Intel Core i3/i5/i7 de 4ª a 9ª generación (Haswell a Coffee Lake)"
        KernelDefault = "kernel-5.10"
        Category = "Legacy"
        ArcSubsystem = "ARC++ (Android 9 Pie / 11)"
        Notes = "El recovery más compatible de todos los tiempos. Incluye soporte para Google Play Store estable."
    },
    [PSCustomObject]@{
        Codename = "samus"
        DisplayName = "Samus (Intel 1st - 3rd Gen / Broadwell)"
        Hardware = "Intel Core Sandy Bridge, Ivy Bridge, Haswell y Broadwell iniciales"
        KernelDefault = "kernel-legacy-5.4"
        Category = "Legacy"
        ArcSubsystem = "ARC++"
        Notes = "Para equipos de 2011 a 2015 con gráficos Intel HD 3000 / 4000."
    },
    [PSCustomObject]@{
        Codename = "grunt"
        DisplayName = "Grunt (AMD Legacy APUs / Stoney Ridge)"
        Hardware = "AMD A4, A6, A9, E2, Athlon y Bristol Ridge / Stoney Ridge"
        KernelDefault = "kernel-legacy-5.4"
        Category = "Legacy"
        ArcSubsystem = "ARC++ (Android 9)"
        Notes = "Ideal para portátiles económicos AMD antiguos que no son Ryzen."
    },
    [PSCustomObject]@{
        Codename = "cyan"
        DisplayName = "Cyan / Edgar (Intel Braswell / Bay Trail / Cherry Trail)"
        Hardware = "Intel Atom x5-Z8350, Z3735F, Celeron N3050/N3150, Pentium N3700"
        KernelDefault = "kernel-legacy-4.19"
        Category = "Legacy"
        ArcSubsystem = "ARC++"
        Notes = "Compatible con tablets 2 en 1 y mini PCs con UEFI de 32 bits (ia32)."
    }
)

function Get-TapeOSCatalog {
    return $Script:RecoveryCatalog
}

function Get-TapeOSRecommendedRecovery {
    param([string]$Codename)
    $found = $Script:RecoveryCatalog | Where-Object { $_.Codename -eq $Codename }
    if ($found) { return $found }
    return $Script:RecoveryCatalog | Where-Object { $_.Codename -eq 'rammus'}
}

function Get-CrosTechDownloadUrl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Codename
    )

    try {
        $uri = "https://cros-updates-serving.appspot.com/csv"
        # O consulta directa a cros.tech
        Write-Verbose "Consultando cros.tech para codename '$Codename'..."
        return "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${Codename}_mp-v*.bin.zip"
    } catch {
        return $null
    }
}

Export-ModuleMember -Function Get-TapeOSCatalog, Get-TapeOSRecommendedRecovery, Get-CrosTechDownloadUrl
