namespace NerdKey.Kit;

/// <summary>All typed errors that the NerdKey SDK can throw.</summary>
public abstract class NerdKeyException : Exception
{
    protected NerdKeyException(string message) : base(message) { }
}

/// <summary>No license has been activated on this machine.</summary>
public sealed class NotActivatedException : NerdKeyException
{
    public NotActivatedException() : base("NerdKey: no activated license found on this machine") { }
}

/// <summary>The license has reached its seat (machine) limit.</summary>
public sealed class SeatLimitExceededException : NerdKeyException
{
    public SeatLimitExceededException() : base("NerdKey: seat limit exceeded for this license") { }
}

/// <summary>The license has expired.</summary>
public sealed class LicenseExpiredException : NerdKeyException
{
    public LicenseExpiredException() : base("NerdKey: license has expired") { }
}

/// <summary>The license has been revoked by the server.</summary>
public sealed class LicenseRevokedException : NerdKeyException
{
    public LicenseRevokedException() : base("NerdKey: license has been revoked") { }
}

/// <summary>Network unavailable but within the grace window — app may continue.</summary>
public sealed class NetworkErrorWithinGraceException : NerdKeyException
{
    public DateTime LastCheckAt { get; }
    public NetworkErrorWithinGraceException(DateTime lastCheckAt)
        : base($"NerdKey: offline — within grace (last online: {lastCheckAt:O})")
    {
        LastCheckAt = lastCheckAt;
    }
}

/// <summary>Network unavailable and grace window has elapsed — block the app.</summary>
public sealed class NetworkErrorGraceExpiredException : NerdKeyException
{
    public DateTime LastCheckAt { get; }
    public NetworkErrorGraceExpiredException(DateTime lastCheckAt)
        : base($"NerdKey: offline grace expired (last online: {lastCheckAt:O})")
    {
        LastCheckAt = lastCheckAt;
    }
}

/// <summary>The offline Ed25519 signature on the license key is invalid.</summary>
public sealed class InvalidSignatureException : NerdKeyException
{
    public InvalidSignatureException() : base("NerdKey: license key signature is invalid") { }
}

/// <summary>General license problem with a descriptive detail.</summary>
public sealed class InvalidLicenseException : NerdKeyException
{
    public InvalidLicenseException(string detail)
        : base($"NerdKey: invalid license — {detail}") { }
}
